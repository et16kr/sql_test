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
- Java UI 사용 시 `java` 필요 (`--ui java`)

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
    -> tests/fullscan/fullscan.ts
    -> tests/hash/hash.ts
    -> ...
```

## 4. 실행 방법

전체 테스트 실행:

```bash
./bin/altitest tests/tests.ts
```

자동화/에이전트 분석용 실행:

```bash
./bin/altitest tests/tests.ts --non-interactive --ai-report
```

특정 케이스만 실행:

```bash
./bin/altitest tests/tests.ts --case 12
# 또는
./bin/altitest tests/tests.ts --case tests/fullscan/01_packed_keyonly.sql
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
| `--accept-out` | FAIL 케이스 `.out -> .lst` 반영 |
| `--accept-missing-only` | `FAIL(missing_lst)`만 반영 |
| `--open-viewdiff` | 실행 후 이슈 있으면 viewdiff 열기 |
| `--ui <cli|java>` | viewdiff UI 선택 |
| `--diff-tool <cmd>` | diff 도구 지정 |
| `--non-interactive` | 비대화식 실행 |
| `--ai-report` | `triage.json`, `summary.txt` 생성 |

## 6. 결과 확인 (viewdiff)

최근 실행 결과 열기:

```bash
./bin/viewdiff
```

특정 run.json 기준:

```bash
./bin/viewdiff --run-json out/runs/<run_id>/run.json
```

Java UI 사용:

```bash
./bin/viewdiff --ui java
```

CLI 모드에서 FAIL/ERROR/ORDER/FATAL 목록 확인 후:

- `o <index>`: diff 열기
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
