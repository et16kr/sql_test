"""Directive parser for SQL files."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Set

from .config import REASON_PARSE_ERROR, REASON_UNKNOWN_DIRECTIVE
from .model import ParseIssue


@dataclass
class DirectiveAction:
    kind: str
    command: str
    lineno: int = 0
    env: Dict[str, str] = field(default_factory=dict)
    unset_env_keys: Set[str] = field(default_factory=set)


@dataclass
class ParseResult:
    preprocessed_sql: str
    hidden_sql: str
    actions: List[DirectiveAction]
    timeout_sec_override: Optional[int]
    issues: List[ParseIssue]
    last_sql_lineno: int = 0
    segments: List["SqlSegment"] = field(default_factory=list)
    visible_env: Dict[str, str] = field(default_factory=dict)
    visible_unset_env_keys: Set[str] = field(default_factory=set)
    hidden_env: Dict[str, str] = field(default_factory=dict)
    hidden_unset_env_keys: Set[str] = field(default_factory=set)


_PREFIX = "--+"


@dataclass
class SqlSegment:
    sql: str
    hidden: bool


def _flush_segment(segments: List[SqlSegment], lines: List[str], hidden: bool) -> None:
    if not lines:
        return
    segments.append(SqlSegment(sql="".join(lines), hidden=hidden))
    lines.clear()


def _parse_set_env(payload: str) -> Dict[str, str]:
    if "=" not in payload:
        raise ValueError("SET_ENV must be KEY=VALUE")
    key, value = payload.split("=", 1)
    key = key.strip()
    value = value.strip()
    if not key:
        raise ValueError("SET_ENV key is empty")
    return {key: value}


def parse_sql_file(sql_path: str) -> ParseResult:
    actions: List[DirectiveAction] = []
    issues: List[ParseIssue] = []
    env_map: Dict[str, str] = {}
    unset_env_keys: Set[str] = set()
    visible_lines: List[str] = []
    hidden_lines: List[str] = []
    segments: List[SqlSegment] = []
    current_lines: List[str] = []
    in_skip = False
    timeout_sec_override: Optional[int] = None
    visible_env: Optional[Dict[str, str]] = None
    visible_unset_env_keys: Optional[Set[str]] = None
    hidden_env: Optional[Dict[str, str]] = None
    hidden_unset_env_keys: Optional[Set[str]] = None
    last_sql_lineno = 0

    path = str(Path(sql_path).resolve())
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except OSError as e:
        return ParseResult(
            preprocessed_sql="",
            hidden_sql="",
            actions=[],
            timeout_sec_override=None,
            last_sql_lineno=0,
            segments=[],
            issues=[ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"failed to read sql: {e}")],
            visible_env={},
            visible_unset_env_keys=set(),
            hidden_env={},
            hidden_unset_env_keys=set(),
        )

    for lineno, raw in enumerate(lines, start=1):
        if raw.startswith(_PREFIX):
            body = raw[len(_PREFIX) :].strip()
            body_upper = body.upper()

            if body_upper.startswith("SYSTEM "):
                if not body.endswith(";"):
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: SYSTEM must end with ';'"))
                    continue
                command = body[len("SYSTEM ") : -1].strip()
                if not command:
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: SYSTEM command empty"))
                    continue
                actions.append(
                    DirectiveAction(
                        kind="SYSTEM",
                        command=command,
                        lineno=lineno,
                        env=dict(env_map),
                        unset_env_keys=set(unset_env_keys),
                    )
                )

            elif body_upper.startswith("SET_ENV "):
                if not body.endswith(";"):
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: SET_ENV must end with ';'"))
                    continue
                payload = body[len("SET_ENV ") : -1].strip()
                try:
                    parsed = _parse_set_env(payload)
                    env_map.update(parsed)
                    unset_env_keys.difference_update(parsed.keys())
                except ValueError as e:
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: {e}"))

            elif body_upper.startswith("UNSET_ENV "):
                if not body.endswith(";"):
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: UNSET_ENV must end with ';'"))
                    continue
                key = body[len("UNSET_ENV ") : -1].strip()
                if not key:
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: UNSET_ENV key empty"))
                else:
                    env_map.pop(key, None)
                    unset_env_keys.add(key)

            elif body_upper.startswith("TIMEOUT_SEC "):
                if not body.endswith(";"):
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: TIMEOUT_SEC must end with ';'"))
                    continue
                payload = body[len("TIMEOUT_SEC ") : -1].strip()
                try:
                    parsed = int(payload)
                except ValueError:
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: TIMEOUT_SEC must be integer -> {payload}"))
                    continue
                if parsed <= 0:
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: TIMEOUT_SEC must be > 0 -> {payload}"))
                    continue
                timeout_sec_override = parsed

            elif body_upper == "SKIP BEGIN;":
                if in_skip:
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: nested SKIP BEGIN not supported"))
                else:
                    _flush_segment(segments, current_lines, hidden=False)
                    in_skip = True

            elif body_upper == "SKIP END;":
                if not in_skip:
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: SKIP END without SKIP BEGIN"))
                else:
                    _flush_segment(segments, current_lines, hidden=True)
                    in_skip = False

            else:
                issues.append(ParseIssue(path=path, reason=REASON_UNKNOWN_DIRECTIVE, detail=f"line {lineno}: unknown directive '{body}'"))
            continue

        if in_skip:
            hidden_lines.append(raw)
            if hidden_env is None and raw.strip() and not raw.lstrip().startswith("--"):
                hidden_env = dict(env_map)
                hidden_unset_env_keys = set(unset_env_keys)
        else:
            visible_lines.append(raw)
            if visible_env is None and raw.strip() and not raw.lstrip().startswith("--"):
                visible_env = dict(env_map)
                visible_unset_env_keys = set(unset_env_keys)
        if raw.strip() and not raw.lstrip().startswith("--"):
            last_sql_lineno = lineno
        current_lines.append(raw)

    if in_skip:
        issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail="SKIP BEGIN without matching SKIP END"))
    else:
        _flush_segment(segments, current_lines, hidden=False)

    return ParseResult(
        preprocessed_sql="".join(visible_lines),
        hidden_sql="".join(hidden_lines),
        actions=actions,
        timeout_sec_override=timeout_sec_override,
        last_sql_lineno=last_sql_lineno,
        segments=segments,
        issues=issues,
        visible_env=visible_env or {},
        visible_unset_env_keys=visible_unset_env_keys or set(),
        hidden_env=hidden_env or {},
        hidden_unset_env_keys=hidden_unset_env_keys or set(),
    )
