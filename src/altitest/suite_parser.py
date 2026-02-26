"""Suite parser for .ts files."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

from .config import REASON_CYCLE_INCLUDE, REASON_PARSE_ERROR, REASON_PATH_OUTSIDE_ROOT
from .model import ParseIssue
from .utils import is_subpath


def parse_suite(
    suite_path: str,
    repo_root: str,
) -> Tuple[List[str], List[ParseIssue], List[str], List[str], Dict[str, str], Dict[str, int]]:
    seen_sql: Set[str] = set()
    seen_ts: Set[str] = set()
    active_stack: List[str] = []
    sql_paths: List[str] = []
    issues: List[ParseIssue] = []
    ts_trace: List[str] = []
    sql_sources: List[str] = []
    ts_parent_map: Dict[str, str] = {}
    sql_timeout_map: Dict[str, int] = {}

    def add_issue(path: str, reason: str, detail: str) -> None:
        issues.append(ParseIssue(path=path, reason=reason, detail=detail))

    def parse_suite_line(line: str, ts_path: str, lineno: int) -> Tuple[Optional[str], Optional[int], bool]:
        path_part = line
        option_part = ""
        if "|" in line:
            path_part, option_part = line.split("|", 1)

        entry = path_part.strip()
        if not entry:
            add_issue(ts_path, REASON_PARSE_ERROR, f"line {lineno}: empty entry before options")
            return None, None, False

        timeout_sec: Optional[int] = None
        if option_part.strip():
            for token in [t.strip() for t in option_part.split(",") if t.strip()]:
                if "=" not in token:
                    add_issue(ts_path, REASON_PARSE_ERROR, f"line {lineno}: invalid option '{token}'")
                    return None, None, False
                key, value = token.split("=", 1)
                key = key.strip().lower()
                value = value.strip()
                if key not in {"timeout", "timeout_sec"}:
                    add_issue(ts_path, REASON_PARSE_ERROR, f"line {lineno}: unknown option '{key}'")
                    return None, None, False
                try:
                    parsed = int(value)
                except ValueError:
                    add_issue(ts_path, REASON_PARSE_ERROR, f"line {lineno}: timeout must be integer -> {value}")
                    return None, None, False
                if parsed <= 0:
                    add_issue(ts_path, REASON_PARSE_ERROR, f"line {lineno}: timeout must be > 0 -> {value}")
                    return None, None, False
                timeout_sec = parsed

        return entry, timeout_sec, True

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

            entry, timeout_sec, ok = parse_suite_line(line, real_ts, lineno)
            if not ok or entry is None:
                continue

            if Path(entry).is_absolute():
                add_issue(real_ts, REASON_PARSE_ERROR, f"line {lineno}: absolute path is not allowed -> {entry}")
                continue
            candidate = str(Path(base_dir, entry).resolve())
            if not is_subpath(candidate, repo_root):
                add_issue(real_ts, REASON_PATH_OUTSIDE_ROOT, f"line {lineno}: outside root -> {entry}")
                continue
            if entry.endswith(".ts"):
                if timeout_sec is not None:
                    add_issue(real_ts, REASON_PARSE_ERROR, f"line {lineno}: timeout option is only allowed for .sql entries")
                    continue
                parse_ts(candidate, real_ts)
            elif entry.endswith(".sql"):
                if not os.path.exists(candidate):
                    add_issue(real_ts, REASON_PARSE_ERROR, f"line {lineno}: missing sql -> {entry}")
                    continue
                if timeout_sec is not None:
                    existing_timeout = sql_timeout_map.get(candidate)
                    if existing_timeout is not None and existing_timeout != timeout_sec:
                        add_issue(
                            real_ts,
                            REASON_PARSE_ERROR,
                            f"line {lineno}: conflicting timeout for sql -> {entry} "
                            f"(existing={existing_timeout}, new={timeout_sec})",
                        )
                        continue
                    sql_timeout_map[candidate] = timeout_sec
                if candidate not in seen_sql:
                    seen_sql.add(candidate)
                    sql_paths.append(candidate)
                    sql_sources.append(real_ts)
            else:
                add_issue(real_ts, REASON_PARSE_ERROR, f"line {lineno}: unsupported entry -> {entry}")

        active_stack.pop()

    parse_ts(suite_path)
    return sql_paths, issues, ts_trace, sql_sources, ts_parent_map, sql_timeout_map
