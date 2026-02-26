"""altitest CLI entrypoint."""

from __future__ import annotations

import argparse
import difflib
import os
import shutil
import subprocess
import sys
import time
from dataclasses import asdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from . import config
from .case_builder import build_case_plans
from .classifier import classify_compare, is_fatal_from_output, status_priority
from .comparator import order_only_mismatch, strict_compare
from .directive_parser import parse_sql_file
from .executor import execute_is, run_shell_command, run_system_actions, write_text
from .healthcheck import is_port_open, resolve_port
from .model import CasePlan, CaseResult, ParseIssue, RunOptions, RunResult
from .recovery import recover_with_clean_and_start
from .reporter import format_case_line, run_result_to_dict, summarize, write_json
from .suite_parser import parse_suite
from .triage import generate_triage
from .utils import ensure_dir, make_run_id, now_utc_iso, repo_relpath


class RunnerContext:
    def __init__(self, options: RunOptions, run_id: str, run_dir: str, suite_abs: str) -> None:
        self.options = options
        self.run_id = run_id
        self.run_dir = run_dir
        self.suite_abs = suite_abs
        self.base_env = dict(os.environ)
        self.port = resolve_port(self.base_env)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="altitest", description="Altibase SQL test runner")
    p.add_argument("suite", help="suite ts file or single sql file")

    p.add_argument(
        "--server-mode",
        default=config.DEFAULT_SERVER_MODE,
        choices=["start-once", "restart-once", "per-case", "none"],
        help="server lifecycle policy",
    )
    p.add_argument(
        "--clean-mode",
        default=config.DEFAULT_CLEAN_MODE,
        choices=["none", "before-suite", "before-each"],
        help="clean timing policy",
    )
    p.add_argument("--allow-clean", action="store_true", help="allow clean command when clean-mode is not none")
    p.add_argument("--timeout-sec", type=int, default=config.DEFAULT_TIMEOUT_SEC, help="timeout per command in seconds")

    p.add_argument("--order-check", default="auto", choices=["auto", "off"], help="ordering mismatch detection policy")
    p.add_argument("--order-is-pass", action="store_true", help="treat ORDER as pass for exit code")
    p.add_argument("--fatal-recover", action="store_true", help="recover on FATAL using clean -> server start")
    p.add_argument("--continue-on-error", action="store_true", help="continue running after ERROR (default: stop on first ERROR)")
    p.add_argument(
        "--fatal-recover-max",
        type=int,
        default=config.DEFAULT_FATAL_RECOVER_MAX,
        help="max recovery attempts per FATAL",
    )
    p.add_argument("--raw-diff", action="store_true", help="disable normalization before compare")

    p.add_argument("--accept-out", action="store_true", help="accept all FAIL cases: out -> lst")
    p.add_argument("--accept-missing-only", action="store_true", help="accept only FAIL(missing_lst): out -> lst")

    p.add_argument("--case", dest="case_filter", default="", help="run a specific case index or sql path")
    p.add_argument("--open-viewdiff", action="store_true", help="open viewdiff after run if issues exist")
    p.add_argument("--ui", default=config.DEFAULT_VIEWDIFF_UI, choices=["cli", "java"], help="viewdiff UI mode")
    p.add_argument("--diff-tool", default="", help="diff command override for viewdiff")
    p.add_argument("--yes", action="store_true", help="auto confirm destructive prompts")
    p.add_argument("--non-interactive", action="store_true", help="disable interactive prompts")
    p.add_argument("--ai-report", action="store_true", help="generate triage.json and summary.txt")

    return p



def parse_options(argv: Optional[List[str]] = None) -> RunOptions:
    args = build_parser().parse_args(argv)
    repo_root = str(Path.cwd().resolve())
    out_dir = str(Path(repo_root, "out").resolve())
    return RunOptions(
        suite=args.suite,
        repo_root=repo_root,
        out_dir=out_dir,
        server_mode=args.server_mode,
        clean_mode=args.clean_mode,
        allow_clean=args.allow_clean,
        timeout_sec=max(1, int(args.timeout_sec)),
        order_check=args.order_check,
        order_is_pass=bool(args.order_is_pass),
        fatal_recover=bool(args.fatal_recover),
        fatal_recover_max=max(1, int(args.fatal_recover_max)),
        continue_on_error=bool(args.continue_on_error),
        raw_diff=bool(args.raw_diff),
        accept_out=bool(args.accept_out),
        accept_missing_only=bool(args.accept_missing_only),
        yes=bool(args.yes),
        non_interactive=bool(args.non_interactive),
        case_filter=str(args.case_filter or "").strip(),
        open_viewdiff=bool(args.open_viewdiff),
        ui=args.ui,
        diff_tool=str(args.diff_tool or "").strip(),
        ai_report=bool(args.ai_report),
    )



def check_required_commands() -> Tuple[bool, str]:
    required = ["is", "clean", "server", "diff"]
    missing = [cmd for cmd in required if shutil.which(cmd) is None]
    if missing:
        return False, f"missing required commands: {', '.join(missing)}"
    return True, ""



def _make_error_result(index: int, sql: str, reason: str, detail: str, suite_abs: str) -> CaseResult:
    return CaseResult(
        index=index,
        sql=sql,
        mode="single",
        status=config.STATUS_ERROR,
        reason=reason,
        lst="",
        out="",
        err="",
        exit_code=1,
        duration_ms=0,
        rerun_cmd="",
        analysis_hint=detail,
    )



def _apply_status(current_status: str, current_reason: str, new_status: str, new_reason: str) -> Tuple[str, str]:
    if status_priority(new_status) <= status_priority(current_status):
        return new_status, new_reason
    return current_status, current_reason



def _write_case_diff(case_dir: str, lst_path: str, out_path: str, exp_norm: str, out_norm: str) -> Dict[str, str]:
    artifacts: Dict[str, str] = {}
    case_path = Path(case_dir)
    case_path.mkdir(parents=True, exist_ok=True)

    lst_norm_path = str(case_path / "lst.norm")
    out_norm_path = str(case_path / "out.norm")
    diff_path = str(case_path / "diff.txt")

    write_text(lst_norm_path, exp_norm)
    write_text(out_norm_path, out_norm)
    diff = difflib.unified_diff(
        exp_norm.splitlines(keepends=True),
        out_norm.splitlines(keepends=True),
        fromfile=lst_path,
        tofile=out_path,
    )
    write_text(diff_path, "".join(diff))

    artifacts["normalized_lst"] = lst_norm_path
    artifacts["normalized_out"] = out_norm_path
    artifacts["diff_text"] = diff_path
    return artifacts



def _run_pre_suite_actions(ctx: RunnerContext) -> None:
    opts = ctx.options
    env = dict(ctx.base_env)

    if opts.clean_mode == "before-suite" and opts.allow_clean:
        run_shell_command("clean", env=env, timeout_sec=opts.timeout_sec)

    if opts.server_mode == "start-once":
        run_shell_command("server start", env=env, timeout_sec=opts.timeout_sec)
    elif opts.server_mode == "restart-once":
        run_shell_command("server stop", env=env, timeout_sec=opts.timeout_sec)
        run_shell_command("server start", env=env, timeout_sec=opts.timeout_sec)



def _run_pre_case_actions(ctx: RunnerContext) -> None:
    opts = ctx.options
    env = dict(ctx.base_env)

    if opts.clean_mode == "before-each" and opts.allow_clean:
        run_shell_command("clean", env=env, timeout_sec=opts.timeout_sec)

    if opts.server_mode == "per-case":
        run_shell_command("server start", env=env, timeout_sec=opts.timeout_sec)



def _run_phase(
    ctx: RunnerContext,
    plan: CasePlan,
    phase_name: str,
    phase_sql: str,
    case_dir: str,
) -> Tuple[str, str, str, str, int, Dict[str, str], bool]:
    """Run one phase and return status, reason, stdout, stderr, exit_code, artifacts, ran."""

    phase_artifacts: Dict[str, str] = {}
    parse_result = parse_sql_file(phase_sql)
    phase_timeout_sec = int(plan.timeout_sec_override or ctx.options.timeout_sec)
    if parse_result.timeout_sec_override is not None:
        phase_timeout_sec = int(parse_result.timeout_sec_override)
    if parse_result.issues:
        issue = parse_result.issues[0]
        phase_artifacts["phase_error_detail"] = issue.detail
        return config.STATUS_ERROR, issue.reason, "", "", 1, phase_artifacts, False

    pre_path = str(Path(case_dir, f"{phase_name}.pre.sql"))
    write_text(pre_path, parse_result.preprocessed_sql)
    if phase_name == "test":
        phase_artifacts["preprocessed_sql"] = pre_path

    ok, system_result = run_system_actions(parse_result.actions, base_env=ctx.base_env, timeout_sec=phase_timeout_sec)
    if not ok:
        if system_result.timed_out:
            return config.STATUS_ERROR, config.REASON_TIMEOUT, system_result.stdout, system_result.stderr, system_result.returncode, phase_artifacts, False
        if is_fatal_from_output(system_result.stdout, system_result.stderr, config.FATAL_PATTERNS):
            return (
                config.STATUS_FATAL,
                config.REASON_SERVER_DISCONNECTED,
                system_result.stdout,
                system_result.stderr,
                system_result.returncode,
                phase_artifacts,
                False,
            )
        return config.STATUS_ERROR, config.REASON_EXEC_FAILED, system_result.stdout, system_result.stderr, system_result.returncode, phase_artifacts, False

    res = execute_is(pre_path, timeout_sec=phase_timeout_sec, env=ctx.base_env)
    phase_stdout_path = str(Path(case_dir, f"{phase_name}.stdout"))
    phase_stderr_path = str(Path(case_dir, f"{phase_name}.stderr"))
    write_text(phase_stdout_path, res.stdout)
    write_text(phase_stderr_path, res.stderr)

    if phase_name == "test":
        write_text(plan.out_path, res.stdout)
        write_text(plan.err_path, res.stderr)
        stderr_case_path = str(Path(case_dir, "stderr.err"))
        write_text(stderr_case_path, res.stderr)
        phase_artifacts["stderr.err"] = stderr_case_path

    if is_fatal_from_output(res.stdout, res.stderr, config.FATAL_PATTERNS):
        return config.STATUS_FATAL, config.REASON_SERVER_DISCONNECTED, res.stdout, res.stderr, res.returncode, phase_artifacts, True

    if not is_port_open("localhost", ctx.port):
        return config.STATUS_FATAL, config.REASON_SERVER_PORT_CLOSED, res.stdout, res.stderr, res.returncode, phase_artifacts, True

    if res.timed_out:
        return config.STATUS_ERROR, config.REASON_TIMEOUT, res.stdout, res.stderr, res.returncode, phase_artifacts, True
    if res.error:
        return config.STATUS_ERROR, config.REASON_EXEC_FAILED, res.stdout, res.stderr, res.returncode, phase_artifacts, True
    if res.returncode != 0:
        return config.STATUS_ERROR, config.REASON_EXEC_FAILED, res.stdout, res.stderr, res.returncode, phase_artifacts, True

    return config.STATUS_PASS, "", res.stdout, res.stderr, res.returncode, phase_artifacts, True



def _run_case(ctx: RunnerContext, plan: CasePlan) -> CaseResult:
    start = time.monotonic()
    case_dir = str(Path(ctx.run_dir, "cases", str(plan.index)))
    ensure_dir(case_dir)

    status = config.STATUS_PASS
    reason = ""
    analysis_hint = "PASS"
    exit_code = 0
    artifacts: Dict[str, str] = {}

    phase_sql = {
        "init": plan.init_sql,
        "test": plan.test_sql,
        "destroy": plan.destroy_sql,
    }

    test_ran = False

    init_phase = next((p for p in plan.phases if p.name == "init"), None)
    test_phase = next((p for p in plan.phases if p.name == "test"), None)
    destroy_phase = next((p for p in plan.phases if p.name == "destroy"), None)

    def _phase_hint(phase: str, st: str, rs: str, arts: Dict[str, str]) -> str:
        detail = arts.get("phase_error_detail", "").strip()
        base = f"{st}: {rs} at {phase} phase"
        if detail:
            return f"{base} ({detail})"
        return base

    if init_phase is not None:
        st, rs, _, _, code, arts, _ = _run_phase(ctx, plan, "init", init_phase.sql_path, case_dir)
        artifacts.update(arts)
        if st in {config.STATUS_ERROR, config.STATUS_FATAL}:
            status, reason = _apply_status(status, reason, st, rs)
            analysis_hint = _phase_hint("init", st, rs, arts)
            exit_code = code

    if status not in {config.STATUS_ERROR, config.STATUS_FATAL} and test_phase is not None:
        st, rs, stdout, _, code, arts, ran = _run_phase(ctx, plan, "test", test_phase.sql_path, case_dir)
        artifacts.update(arts)
        test_ran = ran

        if st in {config.STATUS_ERROR, config.STATUS_FATAL}:
            status, reason = _apply_status(status, reason, st, rs)
            analysis_hint = _phase_hint("test", st, rs, arts)
            exit_code = code
        else:
            lst_exists = Path(plan.lst_path).exists()
            out_text = Path(plan.out_path).read_text(encoding="utf-8", errors="replace") if Path(plan.out_path).exists() else ""
            exp_text = Path(plan.lst_path).read_text(encoding="utf-8", errors="replace") if lst_exists else ""
            strict_same, exp_norm, out_norm = strict_compare(exp_text, out_text, raw_diff=ctx.options.raw_diff)
            order_check_result: Optional[bool] = None
            if not strict_same and ctx.options.order_check == "auto" and lst_exists:
                order_check_result = order_only_mismatch(exp_norm, out_norm)

            cmp_status, cmp_reason, cmp_hint = classify_compare(strict_same, order_check_result, lst_exists)
            status, reason = _apply_status(status, reason, cmp_status, cmp_reason)
            analysis_hint = cmp_hint
            artifacts.update(_write_case_diff(case_dir, plan.lst_path, plan.out_path, exp_norm, out_norm))

    if destroy_phase is not None and status != config.STATUS_FATAL:
        st, rs, _, _, code, arts, _ = _run_phase(ctx, plan, "destroy", destroy_phase.sql_path, case_dir)
        artifacts.update(arts)
        if st in {config.STATUS_ERROR, config.STATUS_FATAL}:
            status, reason = _apply_status(status, reason, st, rs)
            analysis_hint = _phase_hint("destroy", st, rs, arts)
            exit_code = code

    duration_ms = int((time.monotonic() - start) * 1000)
    rerun_cmd = f"altitest {ctx.suite_abs} --case {plan.index}"

    return CaseResult(
        index=plan.index,
        sql=plan.sql_path,
        mode=plan.mode,
        status=status,
        reason=reason,
        lst=plan.lst_path,
        out=plan.out_path,
        err=plan.err_path,
        exit_code=exit_code,
        duration_ms=duration_ms,
        rerun_cmd=rerun_cmd,
        analysis_hint=analysis_hint,
        phase_sql={k: v for k, v in phase_sql.items() if v},
        artifacts=artifacts,
    )



def _filter_case_plans(plans: List[CasePlan], case_filter: str) -> List[CasePlan]:
    if not case_filter:
        return plans
    if case_filter.isdigit():
        target = int(case_filter)
        return [p for p in plans if p.index == target]

    cf = str(Path(case_filter).resolve()) if os.path.exists(case_filter) else case_filter
    filtered: List[CasePlan] = []
    for p in plans:
        if p.sql_path == cf or p.test_sql == cf:
            filtered.append(p)
            continue
        if p.sql_path.endswith(case_filter) or p.test_sql.endswith(case_filter):
            filtered.append(p)
    return filtered



def _accept_results(results: List[CaseResult], opts: RunOptions) -> None:
    if not (opts.accept_out or opts.accept_missing_only):
        return
    if opts.non_interactive and not opts.yes:
        print("accept options require --yes when --non-interactive is used", file=sys.stderr)
        return

    selected: List[CaseResult] = []
    if opts.accept_out:
        selected.extend(
            r
            for r in results
            if r.status == config.STATUS_FAIL
        )
    if opts.accept_missing_only:
        selected.extend(
            r
            for r in results
            if r.status == config.STATUS_FAIL and r.reason == config.REASON_MISSING_LST
        )

    dedup: Dict[int, CaseResult] = {r.index: r for r in selected}
    selected = [dedup[i] for i in sorted(dedup)]
    if not selected:
        return

    if not opts.yes:
        answer = input(f"Apply baseline update for {len(selected)} cases? [y/N]: ").strip().lower()
        if answer not in {"y", "yes"}:
            return

    for r in selected:
        out_file = Path(r.out)
        lst_file = Path(r.lst)
        if not out_file.exists():
            continue
        lst_file.parent.mkdir(parents=True, exist_ok=True)
        if lst_file.exists():
            stamp = time.strftime("%Y%m%d%H%M%S")
            backup = lst_file.with_name(lst_file.name + f".bak.{stamp}")
            shutil.copy2(lst_file, backup)
        shutil.copy2(out_file, lst_file)



def _derive_exit_code(results: List[CaseResult], opts: RunOptions, stop_code: int) -> int:
    if stop_code in {2, 3}:
        return stop_code

    has_fatal = any(r.status == config.STATUS_FATAL for r in results)
    has_error = any(r.status == config.STATUS_ERROR for r in results)
    has_fail = any(r.status == config.STATUS_FAIL for r in results)
    has_order = any(r.status == config.STATUS_ORDER for r in results)

    if has_fatal:
        return 1
    if has_error or has_fail:
        return 1
    if has_order and not opts.order_is_pass:
        return 1
    return 0



def _run_open_viewdiff(opts: RunOptions, run_json_path: str) -> None:
    script = str(Path(opts.repo_root, "bin", "viewdiff"))
    cmd = [sys.executable, script, "--run-json", run_json_path, "--ui", opts.ui]
    if opts.diff_tool:
        cmd.extend(["--diff-tool", opts.diff_tool])
    if opts.non_interactive:
        cmd.append("--non-interactive")
    if opts.yes:
        cmd.append("--yes")
    subprocess.run(cmd, check=False)



def _to_rel_path_safe(path: str, repo_root: str) -> str:
    if not path:
        return ""
    try:
        return repo_relpath(path, repo_root)
    except Exception:
        return path


def _build_ts_chain(ts_path: str, ts_parent_map_abs: Dict[str, str], repo_root: str) -> List[str]:
    if not ts_path:
        return []
    cur = str(Path(ts_path).resolve())
    chain_abs: List[str] = []
    seen: set[str] = set()
    while cur and cur not in seen:
        seen.add(cur)
        chain_abs.append(cur)
        cur = ts_parent_map_abs.get(cur, "")
    chain_abs.reverse()
    if not chain_abs:
        return []
    return [_to_rel_path_safe(p, repo_root) for p in chain_abs]


def main(argv: Optional[List[str]] = None) -> int:
    opts = parse_options(argv)

    ok, msg = check_required_commands()
    if not ok:
        print(msg, file=sys.stderr)
        return 1

    if opts.clean_mode != "none" and not opts.allow_clean:
        print("clean-mode requires --allow-clean", file=sys.stderr)
        return 1

    suite_abs = str(Path(opts.suite).resolve())
    if not Path(suite_abs).exists():
        print(f"suite file not found: {suite_abs}", file=sys.stderr)
        return 1

    run_id = make_run_id()
    started_at = now_utc_iso()
    run_dir = str(Path(opts.out_dir, "runs", run_id))
    out_actual = str(Path(opts.out_dir, "actual"))
    ensure_dir(run_dir)
    ensure_dir(out_actual)

    ctx = RunnerContext(options=opts, run_id=run_id, run_dir=run_dir, suite_abs=suite_abs)

    target_path = Path(suite_abs)
    if target_path.suffix.lower() == ".sql":
        sql_paths = [str(target_path.resolve())]
        parse_issues = []
        ts_trace = []
        sql_sources = [""]
        ts_parent_map_abs: Dict[str, str] = {}
        sql_timeout_map_abs: Dict[str, int] = {}
    elif target_path.suffix.lower() == ".ts":
        sql_paths, parse_issues, ts_trace, sql_sources, ts_parent_map_abs, sql_timeout_map_abs = parse_suite(
            suite_abs, opts.repo_root
        )
    else:
        print("input must be .ts or .sql", file=sys.stderr)
        return 1

    ts_trace_rel = [_to_rel_path_safe(p, opts.repo_root) for p in ts_trace]
    sql_owner_map_abs: Dict[str, str] = {}
    for sql, owner in zip(sql_paths, sql_sources):
        sql_key = str(Path(sql).resolve())
        owner_abs = str(Path(owner).resolve()) if owner else ""
        sql_owner_map_abs[sql_key] = owner_abs
    plans = build_case_plans(sql_paths, opts.repo_root, out_actual, sql_timeout_map=sql_timeout_map_abs)
    plans = _filter_case_plans(plans, opts.case_filter)

    results: List[CaseResult] = []
    stop_code = 0
    stopped_by_fatal = False
    stopped_by_error = False
    stopped_case_index = 0
    current_ts_chain: List[str] = []

    _run_pre_suite_actions(ctx)

    for plan in plans:
        _run_pre_case_actions(ctx)

        owner_abs = sql_owner_map_abs.get(str(Path(plan.sql_path).resolve()), "")
        owner_chain = _build_ts_chain(owner_abs, ts_parent_map_abs, opts.repo_root)
        if owner_chain != current_ts_chain:
            if current_ts_chain:
                print("")
            common = 0
            for left, right in zip(current_ts_chain, owner_chain):
                if left != right:
                    break
                common += 1
            for depth in range(common, len(owner_chain)):
                ts_rel = owner_chain[depth]
                print(f"{'  ' * depth}{ts_rel}")
            current_ts_chain = owner_chain

        case_result = _run_case(ctx, plan)
        case_result.sql = repo_relpath(case_result.sql, opts.repo_root)
        case_result.lst = case_result.lst
        case_result.out = case_result.out
        case_result.err = case_result.err
        results.append(case_result)

        sql_indent = "  " * len(owner_chain)
        print(f"{sql_indent}{format_case_line(case_result.sql, case_result.status)}")
        if case_result.status in {config.STATUS_ERROR, config.STATUS_FATAL} and case_result.analysis_hint:
            print(f"{sql_indent}  -> {case_result.analysis_hint}")

        if case_result.status == config.STATUS_ERROR and not opts.continue_on_error:
            stopped_by_error = True
            stopped_case_index = case_result.index
            stop_code = 1
            break

        if case_result.status == config.STATUS_FATAL:
            stopped_by_fatal = True
            stopped_case_index = case_result.index
            if opts.fatal_recover:
                recovered = False
                fatal_reason = case_result.reason
                for _ in range(opts.fatal_recover_max):
                    ok_recover, _ = recover_with_clean_and_start(ctx.base_env, opts.timeout_sec)
                    if ok_recover:
                        recovered = True
                        break
                if not recovered:
                    case_result.analysis_hint = (
                        f"FATAL recovery failed after {opts.fatal_recover_max} attempt(s); cause={fatal_reason}"
                    )
                    case_result.reason = config.REASON_FATAL_RECOVERY_FAILED
                    stop_code = 3
                    break
            else:
                stop_code = 2
                break

    next_index = max([p.index for p in plans], default=0) + 1
    for issue in parse_issues:
        issue_sql = issue.path
        if Path(issue_sql).exists():
            try:
                issue_sql = repo_relpath(issue_sql, opts.repo_root)
            except Exception:
                pass
        results.append(_make_error_result(next_index, issue_sql, issue.reason, issue.detail, suite_abs))
        next_index += 1

    _accept_results(results, opts)

    ended_at = now_utc_iso()
    summary = summarize(results, total=len(plans) + len(parse_issues))
    run_state = {
        "stopped_by_fatal": bool(stopped_by_fatal),
        "stopped_by_error": bool(stopped_by_error),
        "stopped_case_index": int(stopped_case_index),
        "suite_ts_trace": ts_trace_rel,
        "suite_sql_sources": {
            _to_rel_path_safe(sql, opts.repo_root): _to_rel_path_safe(owner, opts.repo_root)
            for sql, owner in zip(sql_paths, sql_sources)
        },
        "suite_sql_timeouts": {
            _to_rel_path_safe(sql, opts.repo_root): timeout
            for sql, timeout in sql_timeout_map_abs.items()
        },
        "suite_ts_parents": {
            _to_rel_path_safe(child, opts.repo_root): _to_rel_path_safe(parent, opts.repo_root)
            for child, parent in ts_parent_map_abs.items()
        },
    }

    run_result = RunResult(
        schema_version=1,
        run_id=run_id,
        suite=suite_abs,
        started_at=started_at,
        ended_at=ended_at,
        options={
            "server_mode": opts.server_mode,
            "clean_mode": opts.clean_mode,
            "allow_clean": opts.allow_clean,
            "timeout_sec": opts.timeout_sec,
            "fatal_recover": opts.fatal_recover,
            "fatal_recover_max": opts.fatal_recover_max,
            "diff_tool": opts.diff_tool,
            "order_check": opts.order_check,
            "order_is_pass": opts.order_is_pass,
            "continue_on_error": opts.continue_on_error,
            "raw_diff": opts.raw_diff,
            "accept_out": opts.accept_out,
            "accept_missing_only": opts.accept_missing_only,
            "case_filter": opts.case_filter,
            "open_viewdiff": opts.open_viewdiff,
            "ui": opts.ui,
            "yes": opts.yes,
            "non_interactive": opts.non_interactive,
            "ai_report": opts.ai_report,
        },
        summary=summary,
        results=results,
        run_state=run_state,
    )

    run_json_dict = run_result_to_dict(run_result)
    run_json_path = str(Path(run_dir, "run.json"))
    write_json(run_json_path, run_json_dict)
    write_json(str(Path(opts.out_dir, "last_run.json")), run_json_dict)

    if opts.ai_report:
        generate_triage(run_json_dict, run_dir)

    issue_exists = any(r.status in config.ISSUE_STATUSES for r in results)
    if opts.open_viewdiff and issue_exists:
        _run_open_viewdiff(opts, run_json_path)

    exit_code = _derive_exit_code(results, opts, stop_code)

    print("\nSummary:")
    for key in ["total", "executed", "not_run", "pass", "order", "fail", "error", "fatal"]:
        print(f"  {key}: {summary.get(key, 0)}")

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
