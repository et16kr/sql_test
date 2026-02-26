"""Directive parser for SQL files."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

from .config import REASON_PARSE_ERROR, REASON_UNKNOWN_DIRECTIVE
from .model import ParseIssue


@dataclass
class DirectiveAction:
    kind: str
    command: str
    env: Dict[str, str] = field(default_factory=dict)


@dataclass
class ParseResult:
    preprocessed_sql: str
    actions: List[DirectiveAction]
    timeout_sec_override: Optional[int]
    issues: List[ParseIssue]


_PREFIX = "--+"


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
    pre_lines: List[str] = []
    in_skip = False
    timeout_sec_override: Optional[int] = None

    path = str(Path(sql_path).resolve())
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except OSError as e:
        return ParseResult(
            preprocessed_sql="",
            actions=[],
            timeout_sec_override=None,
            issues=[ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"failed to read sql: {e}")],
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
                actions.append(DirectiveAction(kind="SYSTEM", command=command, env=dict(env_map)))

            elif body_upper.startswith("SET_ENV "):
                if not body.endswith(";"):
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: SET_ENV must end with ';'"))
                    continue
                payload = body[len("SET_ENV ") : -1].strip()
                try:
                    parsed = _parse_set_env(payload)
                    env_map.update(parsed)
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
                    in_skip = True

            elif body_upper == "SKIP END;":
                if not in_skip:
                    issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail=f"line {lineno}: SKIP END without BEGIN"))
                else:
                    in_skip = False

            else:
                issues.append(ParseIssue(path=path, reason=REASON_UNKNOWN_DIRECTIVE, detail=f"line {lineno}: unknown directive '{body}'"))
            continue

        if in_skip:
            continue
        pre_lines.append(raw)

    if in_skip:
        issues.append(ParseIssue(path=path, reason=REASON_PARSE_ERROR, detail="SKIP BEGIN without matching SKIP END"))

    return ParseResult(
        preprocessed_sql="".join(pre_lines),
        actions=actions,
        timeout_sec_override=timeout_sec_override,
        issues=issues,
    )
