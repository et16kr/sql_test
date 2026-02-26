"""Suite parser for .ts files."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Dict, List, Set, Tuple

from .config import REASON_CYCLE_INCLUDE, REASON_PARSE_ERROR, REASON_PATH_OUTSIDE_ROOT
from .model import ParseIssue
from .utils import is_subpath


def parse_suite(
    suite_path: str,
    repo_root: str,
) -> Tuple[List[str], List[ParseIssue], List[str], List[str], Dict[str, str]]:
    seen_sql: Set[str] = set()
    seen_ts: Set[str] = set()
    active_stack: List[str] = []
    sql_paths: List[str] = []
    issues: List[ParseIssue] = []
    ts_trace: List[str] = []
    sql_sources: List[str] = []
    ts_parent_map: Dict[str, str] = {}

    def add_issue(path: str, reason: str, detail: str) -> None:
        issues.append(ParseIssue(path=path, reason=reason, detail=detail))

    def parse_ts(ts_path: str, parent_ts: str = "") -> None:
        real_ts = str(Path(ts_path).resolve())
        if real_ts in active_stack:
            chain = " -> ".join(active_stack + [real_ts])
            add_issue(real_ts, REASON_CYCLE_INCLUDE, f"cycle include detected: {chain}")
            return
        if real_ts in seen_ts:
            return
        if not os.path.exists(real_ts):
            add_issue(real_ts, REASON_PARSE_ERROR, "suite file not found")
            return
        if not is_subpath(real_ts, repo_root):
            add_issue(real_ts, REASON_PATH_OUTSIDE_ROOT, "suite path outside repo root")
            return

        seen_ts.add(real_ts)
        ts_trace.append(real_ts)
        ts_parent_map[real_ts] = parent_ts
        active_stack.append(real_ts)

        base_dir = os.path.dirname(real_ts)
        try:
            with open(real_ts, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        except OSError as e:
            add_issue(real_ts, REASON_PARSE_ERROR, f"failed to read suite: {e}")
            active_stack.pop()
            return

        for lineno, raw in enumerate(lines, start=1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if Path(line).is_absolute():
                add_issue(real_ts, REASON_PARSE_ERROR, f"line {lineno}: absolute path is not allowed -> {line}")
                continue
            candidate = str(Path(base_dir, line).resolve())
            if not is_subpath(candidate, repo_root):
                add_issue(real_ts, REASON_PATH_OUTSIDE_ROOT, f"line {lineno}: outside root -> {line}")
                continue
            if line.endswith(".ts"):
                parse_ts(candidate, real_ts)
            elif line.endswith(".sql"):
                if not os.path.exists(candidate):
                    add_issue(real_ts, REASON_PARSE_ERROR, f"line {lineno}: missing sql -> {line}")
                    continue
                if candidate not in seen_sql:
                    seen_sql.add(candidate)
                    sql_paths.append(candidate)
                    sql_sources.append(real_ts)
            else:
                add_issue(real_ts, REASON_PARSE_ERROR, f"line {lineno}: unsupported entry -> {line}")

        active_stack.pop()

    parse_ts(suite_path)
    return sql_paths, issues, ts_trace, sql_sources, ts_parent_map
