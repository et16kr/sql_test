"""Comparison logic for strict and ordering checks."""

from __future__ import annotations

import re
from collections import Counter
from typing import List, Optional, Sequence, Tuple


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = [line.rstrip() for line in text.split("\n")]
    while lines and lines[-1] == "":
        lines.pop()
    return "\n".join(lines) + ("\n" if lines else "")



def strict_compare(expected: str, actual: str, raw_diff: bool) -> Tuple[bool, str, str]:
    if raw_diff:
        exp_norm = expected
        out_norm = actual
    else:
        exp_norm = normalize_text(expected)
        out_norm = normalize_text(actual)
    return exp_norm == out_norm, exp_norm, out_norm


_BANNER_PATTERNS = [
    re.compile(r"^[-]{5,}$"),
    re.compile(r"^Altibase Client Query utility\.?$", re.IGNORECASE),
    re.compile(r"^Release Version", re.IGNORECASE),
    re.compile(r"^Copyright", re.IGNORECASE),
    re.compile(r"^All Rights Reserved", re.IGNORECASE),
    re.compile(r"^ISQL_CONNECTION", re.IGNORECASE),
    re.compile(r"^\[ERR-\d+"),
    re.compile(r"^\d+\s+row(s)?\s+selected\.?$", re.IGNORECASE),
    re.compile(r"^iSQL disconnected", re.IGNORECASE),
]



def _is_ignorable(line: str) -> bool:
    stripped = line.strip()
    if not stripped:
        return True
    for p in _BANNER_PATTERNS:
        if p.search(stripped):
            return True
    return False



def _split_row(line: str) -> Tuple[str, ...]:
    if "|" in line:
        parts = [p.strip() for p in line.split("|") if p.strip()]
        return tuple(parts)
    return tuple(re.split(r"\s+", line.strip()))



def _extract_single_select_rows(text: str) -> Optional[List[Tuple[str, ...]]]:
    lines = [ln.rstrip("\n") for ln in text.splitlines()]
    filtered = [ln.strip() for ln in lines if not _is_ignorable(ln)]
    if len(filtered) < 3:
        return None

    table_lines: List[str] = []
    for ln in filtered:
        if re.match(r"^[=-]{3,}$", ln):
            continue
        table_lines.append(ln)

    if len(table_lines) < 2:
        return None

    header = table_lines[0]
    data_lines = table_lines[1:]
    if not data_lines:
        return None

    rows = [_split_row(row) for row in data_lines]
    if not rows:
        return None

    width = len(rows[0])
    if width == 0:
        return None
    for r in rows:
        if len(r) != width:
            return None

    if len(_split_row(header)) != width:
        return None

    return rows



def order_only_mismatch(expected_norm: str, actual_norm: str) -> Optional[bool]:
    expected_rows = _extract_single_select_rows(expected_norm)
    actual_rows = _extract_single_select_rows(actual_norm)
    if expected_rows is None or actual_rows is None:
        return None

    if Counter(expected_rows) != Counter(actual_rows):
        return False
    return list(expected_rows) != list(actual_rows)

