"""AI triage artifact generation."""

from __future__ import annotations

from pathlib import Path
from typing import Dict, List

from . import config
from .reporter import write_json



def generate_triage(run_json: Dict[str, object], run_dir: str) -> None:
    results = run_json.get("results", [])
    issue_items: List[Dict[str, object]] = []
    for item in results:
        status = item.get("status", "")
        if status in config.ISSUE_STATUSES:
            issue_items.append(
                {
                    "index": item.get("index"),
                    "status": status,
                    "reason": item.get("reason", ""),
                    "sql": item.get("sql", ""),
                    "rerun_cmd": item.get("rerun_cmd", ""),
                    "analysis_hint": item.get("analysis_hint", ""),
                }
            )

    triage = {
        "run_id": run_json.get("run_id", ""),
        "summary": run_json.get("summary", {}),
        "issues": issue_items,
    }

    triage_path = str(Path(run_dir, "triage.json"))
    write_json(triage_path, triage)

    summary_lines = [
        f"run_id: {run_json.get('run_id', '')}",
        f"suite: {run_json.get('suite', '')}",
        "",
        "summary:",
    ]
    for k, v in (run_json.get("summary", {}) or {}).items():
        summary_lines.append(f"  {k}: {v}")
    summary_lines.append("")
    summary_lines.append("issues:")
    for item in issue_items:
        summary_lines.append(
            f"  [{item['index']}] {item['status']} {item['reason']} {item['sql']}"
        )

    summary_path = Path(run_dir, "summary.txt")
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")

