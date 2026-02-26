"""Backend operations shared by viewdiff CLI and Java UI."""

from __future__ import annotations

import difflib
import json
import os
import shlex
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from . import config



def load_run_json(run_json_path: str) -> Dict[str, object]:
    p = Path(run_json_path)
    if not p.exists():
        raise FileNotFoundError(f"run json not found: {run_json_path}")
    with p.open("r", encoding="utf-8") as f:
        return json.load(f)



def issue_items(run_json: Dict[str, object]) -> List[Dict[str, object]]:
    results = run_json.get("results", [])
    out: List[Dict[str, object]] = []
    for item in results:
        status = str(item.get("status", ""))
        if status in config.ISSUE_STATUSES:
            out.append(item)
    return out



def find_result_by_index(run_json: Dict[str, object], index: int) -> Optional[Dict[str, object]]:
    for item in run_json.get("results", []):
        if int(item.get("index", -1)) == index:
            return item
    return None



def _which_command(cmd: str) -> Optional[List[str]]:
    parts = shlex.split(cmd)
    if not parts:
        return None
    if shutil.which(parts[0]):
        return parts
    return None



def resolve_diff_command(override: str) -> Optional[List[str]]:
    if override:
        return _which_command(override)

    env_cmd = os.environ.get("ALTI_DIFF_TOOL", "").strip()
    if env_cmd:
        resolved = _which_command(env_cmd)
        if resolved:
            return resolved

    for cmd in config.DEFAULT_DIFF_TOOL_CHAIN:
        resolved = _which_command(cmd)
        if resolved:
            return resolved

    return None



def _unified_diff_text(lhs_path: str, rhs_path: str) -> str:
    try:
        lhs = Path(lhs_path).read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    except OSError:
        lhs = []
    try:
        rhs = Path(rhs_path).read_text(encoding="utf-8", errors="replace").splitlines(keepends=True)
    except OSError:
        rhs = []
    diff = difflib.unified_diff(lhs, rhs, fromfile=lhs_path, tofile=rhs_path)
    return "".join(diff)



def open_result(item: Dict[str, object], diff_tool_override: str = "") -> Tuple[bool, str]:
    status = str(item.get("status", ""))
    lst_path = str(item.get("lst", ""))
    out_path = str(item.get("out", ""))
    err_path = str(item.get("err", ""))

    if status == config.STATUS_FATAL:
        if err_path and Path(err_path).exists():
            return True, f"FATAL log: {err_path}"
        return False, "FATAL item has no err file"

    if status == config.STATUS_FAIL and str(item.get("reason", "")) == config.REASON_MISSING_LST:
        if out_path and Path(out_path).exists():
            return True, f"missing lst: actual out at {out_path}"
        return False, "missing_lst item has no out file"

    if not lst_path or not out_path:
        return False, "missing lst/out path"
    if not Path(lst_path).exists() or not Path(out_path).exists():
        diff_text = _unified_diff_text(lst_path, out_path)
        return True, diff_text or "unable to open diff; file missing"

    diff_cmd = resolve_diff_command(diff_tool_override)
    if diff_cmd is None:
        diff_text = _unified_diff_text(lst_path, out_path)
        return True, diff_text or "no GUI diff tool and no textual diff"

    try:
        subprocess.Popen(diff_cmd + [lst_path, out_path])
        return True, f"launched diff: {' '.join(diff_cmd)}"
    except Exception as e:  # pragma: no cover - defensive
        return False, f"failed to launch diff: {e}"



def show_missing_lst_out(item: Dict[str, object], max_chars: int = 200000) -> Tuple[bool, str]:
    status = str(item.get("status", ""))
    reason = str(item.get("reason", ""))
    if not (status == config.STATUS_FAIL and reason == config.REASON_MISSING_LST):
        return False, "show out is allowed for FAIL(missing_lst) only"

    out_path = str(item.get("out", ""))
    if not out_path:
        return False, "missing_lst item has no out path"

    out_file = Path(out_path)
    if not out_file.exists():
        return False, f"out file not found: {out_path}"

    text = out_file.read_text(encoding="utf-8", errors="replace")
    truncated = ""
    if len(text) > max_chars:
        text = text[:max_chars]
        truncated = f"\n\n[truncated to first {max_chars} chars]"
    return True, f"OUT FILE: {out_path}\n\n{text}{truncated}"


def accept_out_to_lst(item: Dict[str, object], yes: bool = False) -> Tuple[bool, str]:
    status = str(item.get("status", ""))
    if status != config.STATUS_FAIL:
        return False, "accept is allowed for FAIL status only"

    out_path = str(item.get("out", ""))
    lst_path = str(item.get("lst", ""))
    if not out_path or not lst_path:
        return False, "missing out/lst path"

    out_file = Path(out_path)
    lst_file = Path(lst_path)
    if not out_file.exists():
        return False, f"out file not found: {out_path}"

    lst_file.parent.mkdir(parents=True, exist_ok=True)
    if lst_file.exists():
        stamp = datetime.now().strftime("%Y%m%d%H%M%S")
        backup = lst_file.with_name(lst_file.name + f".bak.{stamp}")
        shutil.copy2(lst_file, backup)

    shutil.copy2(out_file, lst_file)
    return True, f"accepted: {out_file} -> {lst_file}"



def format_issue_list_lines(run_json: Dict[str, object]) -> List[str]:
    lines: List[str] = []
    for item in issue_items(run_json):
        idx = str(item.get("index", ""))
        status = str(item.get("status", ""))
        reason = str(item.get("reason", ""))
        sql = str(item.get("sql", "")).replace("\t", " ")
        lst = str(item.get("lst", "")).replace("\t", " ")
        out = str(item.get("out", "")).replace("\t", " ")
        err = str(item.get("err", "")).replace("\t", " ")
        lines.append("\t".join([idx, status, reason, sql, lst, out, err]))
    return lines
