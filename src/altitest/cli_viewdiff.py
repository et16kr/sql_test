"""viewdiff CLI entrypoint."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional

from . import config
from .viewdiff_backend import (
    accept_out_to_lst,
    find_result_by_index,
    format_issue_list_lines,
    issue_items,
    load_run_json,
    open_result,
    show_missing_lst_out,
)


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _default_run_json_path() -> str:
    return "out/last_run.json"


def _resolve_run_json_path(run_json: str) -> str:
    p = Path(run_json).expanduser()
    if p.is_absolute():
        return str(p)

    candidates: List[Path] = [Path.cwd() / p]

    sql_test_home = os.environ.get("SQL_TEST_HOME", "").strip()
    if sql_test_home:
        candidates.append(Path(sql_test_home).expanduser() / p)

    candidates.append(_repo_root() / p)

    for candidate in candidates:
        if candidate.exists():
            return str(candidate.resolve())

    return str((Path.cwd() / p).resolve())



def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="viewdiff", description="View ORDER/FAIL/ERROR/FATAL items")
    p.add_argument("--run-json", default=_default_run_json_path(), help="path to run json")
    p.add_argument("--ui", default=config.DEFAULT_VIEWDIFF_UI, choices=["cli", "java"], help="view mode")
    p.add_argument("--diff-tool", default="", help="diff command override")
    p.add_argument("--yes", action="store_true", help="auto confirm overwrite actions")
    p.add_argument("--non-interactive", action="store_true", help="print issue list and exit")

    p.add_argument("--list-lines", action="store_true", help=argparse.SUPPRESS)
    p.add_argument("--open-index", type=int, default=0, help=argparse.SUPPRESS)
    p.add_argument("--show-out-index", type=int, default=0, help=argparse.SUPPRESS)
    p.add_argument("--accept-index", type=int, default=0, help=argparse.SUPPRESS)

    return p



def _print_items(items: List[Dict[str, object]]) -> None:
    for item in items:
        idx = item.get("index", "")
        status = item.get("status", "")
        reason = item.get("reason", "")
        sql = item.get("sql", "")
        print(f"[{idx}] {status:<6} {reason:<24} {sql}")



def _interactive_cli(run_json: Dict[str, object], diff_tool: str, yes: bool) -> int:
    while True:
        items = issue_items(run_json)
        if not items:
            print("No ORDER/FAIL/ERROR/FATAL items in run.")
            return 0

        print("\nIssue list:")
        _print_items(items)
        print("\nCommands: o <index>, v <index>, a <index>, r, q")

        raw = input("viewdiff> ").strip()
        if not raw:
            continue
        if raw == "q":
            return 0
        if raw == "r":
            continue

        parts = raw.split()
        if len(parts) != 2 or parts[0] not in {"o", "v", "a"}:
            print("invalid command")
            continue

        try:
            idx = int(parts[1])
        except ValueError:
            print("index must be integer")
            continue

        item = find_result_by_index(run_json, idx)
        if not item:
            print(f"case index not found: {idx}")
            continue

        if parts[0] == "o":
            ok, msg = open_result(item, diff_tool_override=diff_tool)
            print(msg)
            if not ok:
                continue
        elif parts[0] == "v":
            ok, msg = show_missing_lst_out(item)
            print(msg)
            if not ok:
                continue
        else:
            if item.get("status") != config.STATUS_FAIL:
                print("accept only supports FAIL items")
                continue
            if not yes:
                ans = input("accept out -> lst? [y/N]: ").strip().lower()
                if ans not in {"y", "yes"}:
                    continue
            ok, msg = accept_out_to_lst(item, yes=True)
            print(msg)



def _launch_java_ui(args: argparse.Namespace) -> int:
    if shutil.which("java") is None:
        print("java command not found", file=sys.stderr)
        return 1

    repo_root = str(Path(__file__).resolve().parents[2])
    java_src = str(Path(repo_root, "src", "altitest", "ViewDiffUI.java"))
    if not Path(java_src).exists():
        print(f"java ui file not found: {java_src}", file=sys.stderr)
        return 1

    viewdiff_script = str(Path(repo_root, "bin", "viewdiff"))
    cmd = ["java", java_src, sys.executable, viewdiff_script, str(Path(args.run_json).resolve())]
    if args.diff_tool:
        cmd.append(args.diff_tool)

    proc = subprocess.run(cmd)
    return proc.returncode



def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    args.run_json = _resolve_run_json_path(args.run_json)

    try:
        run_json = load_run_json(args.run_json)
    except Exception as e:
        print(str(e), file=sys.stderr)
        return 1

    if args.list_lines:
        for line in format_issue_list_lines(run_json):
            print(line)
        return 0

    if args.open_index:
        item = find_result_by_index(run_json, args.open_index)
        if not item:
            print(f"case index not found: {args.open_index}", file=sys.stderr)
            return 1
        ok, msg = open_result(item, diff_tool_override=args.diff_tool)
        if msg:
            print(msg)
        return 0 if ok else 1

    if args.show_out_index:
        item = find_result_by_index(run_json, args.show_out_index)
        if not item:
            print(f"case index not found: {args.show_out_index}", file=sys.stderr)
            return 1
        ok, msg = show_missing_lst_out(item)
        if msg:
            print(msg)
        return 0 if ok else 1

    if args.accept_index:
        item = find_result_by_index(run_json, args.accept_index)
        if not item:
            print(f"case index not found: {args.accept_index}", file=sys.stderr)
            return 1
        ok, msg = accept_out_to_lst(item, yes=args.yes)
        print(msg)
        return 0 if ok else 1

    if args.non_interactive:
        _print_items(issue_items(run_json))
        return 0

    if args.ui == "java":
        return _launch_java_ui(args)

    return _interactive_cli(run_json, diff_tool=args.diff_tool, yes=args.yes)


if __name__ == "__main__":
    raise SystemExit(main())
