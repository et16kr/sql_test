#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

export PATH="$REPO_ROOT/tests/manual/fakebin:$PATH"
export ALTIBASE_PORT_NO="29999"

assert_json() {
  local code="$1"
  python3 - "$code" <<'PY'
import json
import sys
code = sys.argv[1]
obj = json.load(open('out/last_run.json', 'r', encoding='utf-8'))
ns = {'obj': obj}
exec(code, ns)
PY
}

run_expect() {
  local expected="$1"
  shift
  set +e
  "$@"
  local rc=$?
  set -e
  if [[ "$rc" -ne "$expected" ]]; then
    echo "unexpected exit code: got=$rc expected=$expected cmd=$*" >&2
    exit 1
  fi
}

reset_basic_fixtures() {
  cat > tests/manual/sql/fail.lst <<'LST'
ID VAL
1 A
2 B
2 rows selected.
LST
  if [[ -f tests/manual/sql/missing.lst ]]; then
    unlink tests/manual/sql/missing.lst
  fi
}

echo "[1/6] basic suite (PASS/ORDER/FAIL/ERROR)"
reset_basic_fixtures
run_expect 1 ./bin/altitest tests/manual/suites/basic.ts --non-interactive --ai-report
assert_json "
summary = obj['summary']
assert summary['pass'] == 5, summary
assert summary['order'] == 1, summary
assert summary['fail'] == 2, summary
assert summary['error'] == 1, summary
assert summary['fatal'] == 0, summary
"

echo "[2/6] fatal stop"
run_expect 2 ./bin/altitest tests/manual/suites/fatal_stop.ts --non-interactive
assert_json "
summary = obj['summary']
assert summary['fatal'] == 1, summary
assert summary['not_run'] == 1, summary
r2 = obj['results'][1]
assert r2['status'] == 'FATAL', r2
assert r2['reason'] == 'server_port_closed', r2
"

echo "[3/6] fatal recover success"
run_expect 1 ./bin/altitest tests/manual/suites/fatal_recover.ts --fatal-recover --fatal-recover-max 2 --non-interactive
assert_json "
summary = obj['summary']
assert summary['pass'] == 2, summary
assert summary['fatal'] == 1, summary
assert summary['not_run'] == 0, summary
"

echo "[4/6] fatal recover fail"
run_expect 3 env FAKE_CLEAN_FAIL=1 ./bin/altitest tests/manual/suites/fatal_recover.ts --fatal-recover --fatal-recover-max 1 --non-interactive
assert_json "
r2 = obj['results'][1]
assert r2['status'] == 'FATAL', r2
assert r2['reason'] == 'fatal_recovery_failed', r2
"

echo "[5/6] parse issues"
run_expect 1 ./bin/altitest tests/manual/suites/parse_issues.ts --non-interactive
assert_json "
reasons = [r['reason'] for r in obj['results'] if r['status'] == 'ERROR']
assert 'cycle_include' in reasons, reasons
assert 'parse_error' in reasons, reasons
assert 'path_outside_root' in reasons, reasons
"

echo "[6/6] viewdiff list"
run_expect 0 ./bin/viewdiff --run-json out/last_run.json --non-interactive > /tmp/viewdiff_smoke.out
if ! rg -q 'ERROR' /tmp/viewdiff_smoke.out; then
  echo "viewdiff smoke failed: ERROR line missing" >&2
  exit 1
fi

echo "smoke OK"
