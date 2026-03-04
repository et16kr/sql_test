# Altibase SQL Test Runner

Altibase SQL 테스트를 Python으로 실행하고 `PASS / ORDER / FAIL / ERROR / FATAL`로 판정하는 로컬 테스트 러너입니다.

- 실행기: `altitest`
- 결과 열람기: `viewdiff`
- 핵심 문서:
  - [요구사항](REQUIREMENTS_SQL_TEST_RUNNER.md)
  - [설계](DESIGN_SQL_TEST_RUNNER.md)

## 1. 요구 환경

- OS: Linux
- Python: 3.9+
- PATH에서 아래 명령이 해석되어야 함
  - `is`
  - `clean`
  - `server`
  - `diff`
- 기본 UI는 Java 이며 `java` 명령이 필요

명령 확인:

```bash
command -v is clean server diff
```

## 2. 설치/빌드

빌드가 필요 없습니다.

```bash
cd /home/et16/sql_test
```

바로 실행:

```bash
./bin/altitest --help
./bin/viewdiff --help
```

## 3. 테스트 파일 구조

- 입력 SQL: `*.sql`
- 기대 결과: `*.lst`
- 실제 결과: `*.out`
- suite 파일: `*.ts` (각 줄에 상대경로)
- `*.ts` 안에 다른 `*.ts` 포함 가능

예시 suite:

```text
tests/tests.ts
  -> tests/all.ts
    -> tests/disk_temp_table/disk_temp_table.ts
      -> tests/disk_temp_table/sort/sort.ts
      -> tests/disk_temp_table/hash/hash.ts
    -> ...
```

### 3.1 `--+` 디렉티브 문법

SQL 파일에서 줄 시작이 `--+` 인 라인은 러너가 먼저 해석하는 제어 디렉티브입니다.

지원 키워드:

- `--+SYSTEM <shell command>;`
- `--+SET_ENV <KEY>=<VALUE>;`
- `--+UNSET_ENV <KEY>;`
- `--+TIMEOUT_SEC <n>;`
- `--+SKIP BEGIN;`
- `--+SKIP END;`

주의사항:

- 디렉티브는 반드시 줄 시작이 `--+` 이어야 합니다.
- `SYSTEM`/`SET_ENV`/`UNSET_ENV` 는 반드시 `;` 로 끝나야 합니다.
- `TIMEOUT_SEC` 는 초 단위 정수(`> 0`)여야 하며 `;` 로 끝나야 합니다.
- `SKIP` 문법은 `SKIP BEGIN;` / `SKIP END;` 만 허용됩니다.
- `SKIP_BEGIN;`, `SKIP_END;` 같은 형태는 지원하지 않습니다.

예시:

```sql
--+SET_ENV ALTIBASE_PORT_NO=20300;
--+TIMEOUT_SEC 600;
--+SYSTEM server start;
--+SKIP BEGIN;
drop table t1;
--+SKIP END;
```

### 3.2 `.ts`에서 케이스별 timeout 지정

`.ts` 엔트리 한 줄에 옵션을 붙일 수 있습니다.

```text
./disk_temp_table/sort/16_temp_row_mode2_wide_payload.sql | timeout_sec=600
./disk_temp_table/sort/15_temp_row_mode2_compact_payload.sql | timeout=300
```

주의사항:

- 옵션은 `.sql` 엔트리에만 허용됩니다. (`.ts` include 라인에는 사용 불가)
- `timeout` / `timeout_sec` 키만 지원합니다.
- 값은 초 단위 정수(`> 0`)여야 합니다.

## 4. 실행 방법

전체 테스트 실행:

```bash
./bin/altitest tests/tests.ts
```

단일 SQL 1건만 바로 실행:

```bash
./bin/altitest tests/window/04_window_resort_varmix.sql
```

실행 출력은 `.ts` 단위로 그룹화됩니다.
상위 `.ts` 포함 관계까지 함께 출력되며, 마지막(leaf) `.ts` 아래 SQL 결과가 출력됩니다.

```text
tests/tests.ts
  tests/all.ts
    tests/disk_temp_table/hash/hash.ts
      tests/disk_temp_table/hash/area_inout/area_inout.ts
        tests/disk_temp_table/hash/area_inout/01_forced_inmemory_hash_area.sql ..... PASS
        tests/disk_temp_table/hash/area_inout/02_forced_outmemory_hash_area.sql .... FAIL
```

자동화/에이전트 분석용 실행:

```bash
./bin/altitest tests/tests.ts --non-interactive --ai-report
```

특정 케이스만 실행:

```bash
./bin/altitest tests/tests.ts --case 12
# 또는
./bin/altitest tests/tests.ts --case tests/disk_temp_table/sort/01_packed_keyonly.sql
```

FATAL 발생 시 복구하고 계속:

```bash
./bin/altitest tests/tests.ts --fatal-recover --fatal-recover-max 3
```

`clean`을 자동 실행하려면 반드시 `--allow-clean` 추가:

```bash
./bin/altitest tests/tests.ts --clean-mode before-each --allow-clean
```

## 5. 주요 옵션

| 옵션 | 설명 |
|---|---|
| `--server-mode <start-once|restart-once|per-case|none>` | 서버 시작 정책 |
| `--clean-mode <none|before-suite|before-each>` | clean 실행 시점 |
| `--allow-clean` | clean 허용 스위치 |
| `--timeout-sec <n>` | 명령 타임아웃(초) |
| `--order-check <auto|off>` | ORDER 판정 사용 여부 |
| `--order-is-pass` | ORDER를 종료코드 0으로 취급 |
| `--fatal-recover` | FATAL 시 `clean -> server start` 복구 |
| `--fatal-recover-max <n>` | 복구 최대 시도 횟수 |
| `--continue-on-error` | ERROR 발생 후에도 다음 케이스 계속 실행 (기본은 첫 ERROR에서 중단) |
| `--accept-out` | FAIL 케이스 `.out -> .lst` 반영 |
| `--accept-missing-only` | `FAIL(missing_lst)`만 반영 |
| `--open-viewdiff` | 실행 후 이슈 있으면 viewdiff 열기 |
| `--ui <cli|java>` | viewdiff UI 선택 (기본: `java`) |
| `--diff-tool <cmd>` | diff 도구 지정 (기본 자동 탐색: `meld -> kdiff3 -> code --diff`) |
| `--non-interactive` | 비대화식 실행 |
| `--ai-report` | `triage.json`, `summary.txt` 생성 |

timeout 우선순위:

1. SQL 디렉티브 `--+TIMEOUT_SEC <n>;`
2. `.ts` 엔트리 옵션 `| timeout_sec=<n>` (또는 `timeout=<n>`)
3. CLI 옵션 `--timeout-sec <n>`

## 6. 결과 확인 (viewdiff)

최근 실행 결과 열기:

```bash
./bin/viewdiff
```

특정 run.json 기준:

```bash
./bin/viewdiff --run-json out/runs/<run_id>/run.json
```

`--run-json` 기본값은 `out/last_run.json` 이며, `viewdiff`는 다음 순서로 경로를 찾습니다.

1. 현재 작업 디렉터리 기준 (`./out/last_run.json`)
2. `$SQL_TEST_HOME` 기준 (`$SQL_TEST_HOME/out/last_run.json`)
3. `viewdiff` 설치 경로 기준 (`<sql_test>/out/last_run.json`)

그래서 테스트를 실행한 위치가 어디든 해당 run을 우선 찾고, 없으면 공용 기본 경로를 자동으로 찾습니다.

Java UI 사용 (기본값):

```bash
./bin/viewdiff
```

CLI UI로 강제:

```bash
./bin/viewdiff --ui cli
```

Java UI에서 `View OUT` 버튼을 누르면 `out` 내용이 별도 창으로 열립니다.
이 창은 크기 조절이 가능하며, `FAIL` 케이스는 창 안의 `Accept OUT -> LST` 버튼으로 바로 반영할 수 있습니다.

diff 도구는 기본적으로 `meld -> kdiff3 -> code --diff` 순서로 자동 선택합니다.
필요하면 `--diff-tool "<cmd>"` 또는 `ALTI_DIFF_TOOL` 환경변수로 강제할 수 있습니다.

주의 (VS Code Snap 터미널):

- Snap 환경(`SNAP_NAME=code`)에서는 `GTK_PATH`, `GIO_MODULE_DIR` 같은 변수가 일반 GUI 앱(`meld`) 실행을 깨뜨릴 수 있습니다.
- `viewdiff`는 내부에서 diff 도구 실행 환경을 자동 정리하므로, Snap 터미널에서도 `meld`를 직접 띄울 수 있습니다.

CLI 모드에서 FAIL/ERROR/ORDER/FATAL 목록 확인 후:

- `o <index>`: diff 열기
- `v <index>`: `FAIL(missing_lst)` 케이스의 `out` 본문 보기
- `a <index>`: FAIL 케이스 `out -> lst` 반영
- `r`: 새로고침
- `q`: 종료

비대화식 목록 출력:

```bash
./bin/viewdiff --non-interactive
```

## 7. 산출물

실행 결과는 `out/` 아래에 저장됩니다.

- `out/last_run.json`
- `out/runs/<run_id>/run.json`
- `out/runs/<run_id>/triage.json` (`--ai-report`)
- `out/runs/<run_id>/summary.txt` (`--ai-report`)
- `out/runs/<run_id>/cases/<index>/`
  - `diff.txt`
  - `lst.norm`
  - `out.norm`
  - `stderr.err`
  - `test.pre.sql`

## 8. 종료코드

- `0`: PASS만 존재, 또는 `--order-is-pass` + PASS/ORDER만 존재
- `1`: ORDER/FAIL/ERROR 존재
- `2`: FATAL로 중단
- `3`: FATAL 복구 실패

## 9. 빠른 검증 (모킹 스모크)

Altibase 없이 동작 검증:

```bash
tests/manual/run_smoke.sh
```

이 스크립트는 `PASS/ORDER/FAIL/ERROR/FATAL` 및 복구 경로를 자동 확인합니다.

## 10. 트러블슈팅

필수 명령 누락:

```text
missing required commands: is, clean, server, diff
```

- Altibase 실행 환경 스크립트를 먼저 로드하거나 PATH를 설정하세요.

`clean-mode requires --allow-clean` 오류:

- `--clean-mode` 사용 시 `--allow-clean`을 같이 지정해야 합니다.

FATAL이 자주 발생하는 경우:

- `ALTIBASE_PORT_NO` 값과 서버 상태를 확인하세요.
- 필요하면 `--fatal-recover --fatal-recover-max <n>` 옵션을 사용하세요.
