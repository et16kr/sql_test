"""Reporting and JSON serialization."""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path
from typing import Dict, Iterable, List

from . import config
from .model import CaseResult, RunResult



def format_case_line(sql_path: str, status: str, width: int = config.DEFAULT_LINE_WIDTH) -> str:
    label = sql_path
    status_block = f" {status}"
    dot_space = max(1, width - len(label) - len(status_block))
    if dot_space < 6 and len(label) > 20:
        keep = max(8, width - len(status_block) - 8)
        half = max(3, keep // 2 - 2)
        label = f"{label[:half]}...{label[-half:]}"
        dot_space = max(1, width - len(label) - len(status_block))
    return f"{label} {'.' * dot_space}{status_block}"



def summarize(results: Iterable[CaseResult], total: int) -> Dict[str, int]:
    counts = {
        "total": total,
        "executed": 0,
        "not_run": 0,
        "pass": 0,
        "order": 0,
        "fail": 0,
        "error": 0,
        "fatal": 0,
    }
    for r in results:
        counts["executed"] += 1
        if r.status == config.STATUS_PASS:
            counts["pass"] += 1
        elif r.status == config.STATUS_ORDER:
            counts["order"] += 1
        elif r.status == config.STATUS_FAIL:
            counts["fail"] += 1
        elif r.status == config.STATUS_ERROR:
            counts["error"] += 1
        elif r.status == config.STATUS_FATAL:
            counts["fatal"] += 1
    counts["not_run"] = max(0, total - counts["executed"])
    return counts



def write_json(path: str, data: object) -> None:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)



def run_result_to_dict(result: RunResult) -> Dict[str, object]:
    return asdict(result)
