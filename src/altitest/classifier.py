"""Classification logic for case statuses."""

from __future__ import annotations

from typing import Iterable, Optional, Tuple

from . import config


def is_fatal_from_output(stdout: str, stderr: str, patterns: Iterable[str]) -> bool:
    combined = f"{stdout}\n{stderr}".lower()
    matched = [pattern.lower() for pattern in patterns if pattern.lower() in combined]
    if not matched:
        return False

    weak_banner = "isql_connection = tcp"
    strong_markers = {
        "err-50032",
        "client unable to establish connection",
        "failed to invoke the connect() system function",
    }

    if any(marker in combined for marker in strong_markers):
        return True

    only_weak_banner = all(m == weak_banner for m in matched)
    if only_weak_banner:
        # iSQL connection banner alone is printed in normal runs.
        return False

    return True



def classify_compare(strict_same: bool, order_check_result: Optional[bool], lst_exists: bool) -> Tuple[str, str, str]:
    if not lst_exists:
        return config.STATUS_FAIL, config.REASON_MISSING_LST, "FAIL: baseline lst missing"
    if strict_same:
        return config.STATUS_PASS, "", "PASS: strict compare equal"
    if order_check_result is True:
        return config.STATUS_ORDER, config.REASON_ORDERING_MISMATCH, "ORDER: same row multiset, different ordering"
    return config.STATUS_FAIL, config.REASON_CONTENT_MISMATCH, "FAIL: content mismatch"



def status_priority(status: str) -> int:
    # lower is higher priority
    if status == config.STATUS_FATAL:
        return 0
    if status == config.STATUS_ERROR:
        return 1
    if status == config.STATUS_ORDER:
        return 2
    if status == config.STATUS_FAIL:
        return 3
    return 4
