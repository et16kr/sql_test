# Altibase SQL Test Runner 요구사항 명세서

## 1. 문서 목적
이 문서는 Altibase SQL 테스트 러너의 요구사항을 정의한다.
설계/구현 상세는 별도 문서 `DESIGN_SQL_TEST_RUNNER.md`에서 다룬다.

## 2. 범위
- 대상: Altibase SQL 테스트 자동 실행/판정/결과 열람 도구
- 실행 환경: Linux + Python (빌드 단계 없음)
- 주요 사용자:
  - 로컬에서 직접 테스트를 실행하는 사용자
  - 테스트 실행/분석을 에이전트에 위임하는 사용자

## 3. 기능 요구사항

### 3.1 기본 실행
- `RQ-F-001`: 빌드 없이 Python으로 실행 가능해야 한다.
- `RQ-F-002`: `altitest <suite.ts>` 형태로 테스트를 실행해야 한다.
- `RQ-F-003`: Altibase 실행 환경(`is`, `clean`, `server`)을 사용해야 한다.

### 3.2 입력/출력 파일
- `RQ-F-010`: `*.ts`는 테스트 목록 파일이며 각 라인은 상대경로여야 한다.
- `RQ-F-011`: `*.ts` 내부에 다른 `*.ts`를 포함할 수 있어야 한다.
- `RQ-F-012`: 테스트 입력은 `*.sql`이어야 한다.
- `RQ-F-013`: 기대 결과는 `*.lst`여야 한다.
- `RQ-F-014`: 실제 결과는 `*.out`이어야 한다.
- `RQ-F-015`: `*.lst`가 없어도 테스트는 수행되며 결과는 `FAIL(missing_lst)`로 표시해야 한다.

### 3.3 케이스 구성
- `RQ-F-020`: 단일 파일형을 지원해야 한다. (한 SQL 안에 생성/테스트/정리 포함)
- `RQ-F-021`: 3단계형(`init.sql`, `test.sql`, `destroy.sql`)을 지원해야 한다.
- `RQ-F-022`: 3단계형 비교 기준은 `test.sql`의 `test.out` vs `test.lst`여야 한다.

### 3.4 SQL 지시어(`--+`)
- `RQ-F-030`: `--+` 지시어는 라인 선두(1열)에서만 인식해야 한다.
- `RQ-F-031`: 지원 지시어는 `SYSTEM`, `SET_ENV`, `UNSET_ENV`, `SKIP BEGIN/END`이다.
- `RQ-F-032`: 지시어는 SQL 실행 전 파일 내 순서대로 처리해야 한다.
- `RQ-F-033`: `SET_ENV`는 `UNSET_ENV` 전까지 같은 SQL 파일의 이후 `SYSTEM`에 적용되어야 한다.
- `RQ-F-034`: `SET_ENV` 스코프는 SQL 파일 경계를 넘으면 초기화되어야 한다.

### 3.5 판정 상태
- `RQ-F-040`: 상태는 `PASS`, `ORDER`, `FAIL`, `ERROR`, `FATAL`을 지원해야 한다.
- `RQ-F-041`: `ORDER`는 `FAIL`과 별도 상태여야 한다.
- `RQ-F-042`: `FATAL`은 서버 연결 단절/접속 불가 상황을 의미해야 한다.
- `RQ-F-043`: `FATAL` 발생 시 기본 동작은 즉시 중단이어야 한다.
- `RQ-F-044`: `--fatal-recover` 옵션 시 `clean -> server start` 후 다음 테스트를 계속해야 한다.
- `RQ-F-045`: `--fatal-recover` 시 방금 `FATAL`이 난 케이스는 재실행하지 않아야 한다.
- `RQ-F-046`: 각 SQL 실행 직후 `ALTIBASE_PORT_NO` 포트 상태를 확인해야 하며, 포트가 닫혀 있으면 방금 실행한 케이스를 `FATAL(server_port_closed)`로 판정해야 한다.

### 3.6 비교/판정
- `RQ-F-050`: 기본 비교는 `.lst` vs `.out` diff 기반이어야 한다.
- `RQ-F-051`: 비교 불일치 시 order-insensitive 비교가 가능하면 `ORDER`로 판정해야 한다.
- `RQ-F-052`: 초기 버전의 ORDER 판정은 파싱 가능한 단일 SELECT 결과(표 형식)에만 적용해야 한다.
- `RQ-F-053`: ORDER 판정 파싱이 불가능한 경우는 `FAIL(content_mismatch)`로 처리해야 한다.
- `RQ-F-054`: 내용 자체가 다르면 `FAIL(content_mismatch)`여야 한다.

### 3.7 출력/보고
- `RQ-F-060`: 콘솔 출력은 상태 컬럼 정렬이 고정되어야 한다.
- `RQ-F-061`: 형식은 `파일명 .... STATUS` 형태를 유지해야 한다.
- `RQ-F-062`: run 결과는 `out/last_run.json` 및 run별 결과 파일로 저장해야 한다.
- `RQ-F-063`: AI 분석 보조를 위한 `--ai-report` 산출물을 제공해야 한다.

### 3.8 viewdiff
- `RQ-F-070`: `viewdiff`로 ORDER/FAIL/ERROR/FATAL 목록을 확인할 수 있어야 한다.
- `RQ-F-071`: 번호 선택 또는 UI 선택으로 항목을 열 수 있어야 한다.
- `RQ-F-072`: X-window diff 도구를 사용해야 한다.
- `RQ-F-073`: 마우스 선택 UI(`--ui java`)를 지원해야 한다.
- `RQ-F-074`: FAIL 목록 도구에서 테스트를 선택하고 `.out -> .lst` 덮어쓰기 버튼으로 기준값을 갱신할 수 있어야 한다.

### 3.9 LST 갱신
- `RQ-F-080`: `.out -> .lst` 갱신 기능을 제공해야 한다.
- `RQ-F-081`: `--accept-out`, `--accept-missing-only`를 지원해야 한다.
- `RQ-F-082`: 갱신 전 백업(`.bak.<timestamp>`)을 생성해야 한다.
- `RQ-F-083`: viewdiff UI의 덮어쓰기 버튼은 기본적으로 FAIL 선택 항목에 대해 동작해야 한다.
- `RQ-F-084`: `--accept-out`은 기본적으로 FAIL 케이스에만 적용해야 하며 ORDER 케이스는 포함하지 않는다.

### 3.10 사용자/에이전트 협업
- `RQ-F-090`: 사용자가 직접 실행 가능한 인터페이스를 제공해야 한다.
- `RQ-F-091`: 에이전트가 원인 분석 가능한 산출물(재실행 명령, diff, 정규화 결과)을 제공해야 한다.
- `RQ-F-092`: UI 도구 없이도 에이전트가 결과를 판별할 수 있도록 machine-readable 결과(`run.json`, `triage.json`)를 제공해야 한다.
- `RQ-F-093`: 자동화 실행 시 `--non-interactive` + `--ai-report` 조합으로 분석 가능한 결과 파일을 생성해야 한다.

## 4. 비기능 요구사항
- `RQ-N-001`: 단일 머신 로컬 실행 가능해야 한다.
- `RQ-N-002`: 실행 재현성을 위해 run별 아티팩트를 보존해야 한다.
- `RQ-N-003`: 파괴적 동작(`clean`, 덮어쓰기)은 안전장치가 있어야 한다.
- `RQ-N-004`: 기본 사용 흐름은 단순해야 한다.

## 5. 운영/환경 요구사항
- `RQ-E-001`: Altibase 서버/클라이언트 명령이 PATH 또는 환경에서 해석되어야 한다.
- `RQ-E-002`: 매뉴얼은 `doc/altibase-docs/Manuals/Altibase_trunk`에서 참조 가능해야 한다.
- `RQ-E-003`: X-window 환경에서 diff 도구를 실행할 수 있어야 한다.
- `RQ-E-004`: `ALTIBASE_PORT_NO`를 사용해 서버 포트 헬스체크가 가능해야 한다.

## 6. 기본 종료코드 요구사항
- `RQ-X-001`: 정상(PASS 또는 옵션에 따른 PASS/ORDER) 완료 시 0
- `RQ-X-002`: ORDER/FAIL/ERROR 존재 시 1
- `RQ-X-003`: FATAL 중단 시 2
- `RQ-X-004`: FATAL 복구 실패 시 3

## 7. 제외 범위(현 단계)
- 고급 SQL 파서 기반 완전한 result-set semantic 비교
- 분산 실행/원격 실행 오케스트레이션
- CI 전용 리포트 포맷의 완전 지원(JUnit 등)
