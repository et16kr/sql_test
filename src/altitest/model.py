"""Dataclasses used by runner and report modules."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional


@dataclass
class RunOptions:
    suite: str
    repo_root: str
    out_dir: str
    server_mode: str
    clean_mode: str
    allow_clean: bool
    timeout_sec: int
    order_check: str
    order_is_pass: bool
    fatal_recover: bool
    fatal_recover_max: int
    raw_diff: bool
    accept_out: bool
    accept_missing_only: bool
    yes: bool
    non_interactive: bool
    case_filter: str
    open_viewdiff: bool
    ui: str
    diff_tool: str
    ai_report: bool


@dataclass
class PhasePlan:
    name: str
    sql_path: str


@dataclass
class CasePlan:
    index: int
    sql_path: str
    mode: str
    phases: List[PhasePlan] = field(default_factory=list)
    init_sql: str = ""
    test_sql: str = ""
    destroy_sql: str = ""
    lst_path: str = ""
    out_path: str = ""
    err_path: str = ""


@dataclass
class ParseIssue:
    path: str
    reason: str
    detail: str


@dataclass
class CaseResult:
    index: int
    sql: str
    mode: str
    status: str
    reason: str
    lst: str
    out: str
    err: str
    exit_code: int = 0
    duration_ms: int = 0
    rerun_cmd: str = ""
    analysis_hint: str = ""
    phase_sql: Dict[str, str] = field(default_factory=dict)
    artifacts: Dict[str, str] = field(default_factory=dict)


@dataclass
class RunResult:
    schema_version: int
    run_id: str
    suite: str
    started_at: str
    ended_at: str
    options: Dict[str, object]
    summary: Dict[str, int]
    results: List[CaseResult]
    run_state: Dict[str, object]

