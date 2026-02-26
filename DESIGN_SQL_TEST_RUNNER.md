# Altibase SQL Test Runner 설계 문서

## 1. 목적
이 문서는 `REQUIREMENTS_SQL_TEST_RUNNER.md`의 요구사항을 구현하기 위한 상세 설계를 정의한다.

## 2. 요구사항 추적

| 요구사항 | 설계 섹션 |
|---|---|
| RQ-F-001~003 | 3, 4, 6 |
| RQ-F-010~015 | 5, 7 |
| RQ-F-020~022 | 6.2 |
| RQ-F-030~034 | 5.2, 6.3 |
| RQ-F-040~045 | 7, 8 |
| RQ-F-050~054 | 7 |
| RQ-F-060~063 | 9, 10 |
| RQ-F-070~073 | 11 |
| RQ-F-080~082 | 12 |
| RQ-F-090~093 | 10.4, 13 |
| RQ-N-* / RQ-E-* / RQ-X-* | 4, 8, 9, 10 |

## 3. 시스템 구성

### 3.1 실행 엔트리
- `bin/altitest`: 테스트 실행기
- `bin/viewdiff`: 결과 열람기

### 3.2 모듈 구성
- `src/altitest/config.py`: 기본값/패턴/옵션 정합성
- `src/altitest/suite_parser.py`: `.ts` 재귀 파싱
- `src/altitest/case_builder.py`: single/triple 케이스 계획 생성
- `src/altitest/directive_parser.py`: `--+` 지시어 파싱
- `src/altitest/executor.py`: `SYSTEM`, `is`, `clean`, `server` 실행
- `src/altitest/healthcheck.py`: `ALTIBASE_PORT_NO` 포트 헬스체크
- `src/altitest/comparator.py`: strict + order-insensitive 비교
- `src/altitest/classifier.py`: PASS/ORDER/FAIL/ERROR/FATAL 분류
- `src/altitest/recovery.py`: FATAL 복구 로직
- `src/altitest/reporter.py`: 콘솔 출력, JSON 저장
- `src/altitest/viewdiff_backend.py`: 목록 로드/항목 오픈/갱신
- `src/altitest/triage.py`: `--ai-report` 생성

### 3.3 설계 원칙
- 기본 사용은 단순(`altitest`, `viewdiff`)
- 고급 기능은 옵션으로 분리
- 파괴적 동작은 명시 옵션 또는 복구 예외 경로에서만 허용

## 4. 디렉터리 및 산출물

```text
sql_test/
  REQUIREMENTS_SQL_TEST_RUNNER.md
  DESIGN_SQL_TEST_RUNNER.md
  doc/
    altibase-docs/Manuals/Altibase_trunk/
  suite/
    a.ts
  sql/
    ...
  out/
    last_run.json
    runs/
      <run_id>/
        run.json
        triage.json
        summary.txt
        logs/
        cases/
          <case_index>/
            diff.txt
            lst.norm
            out.norm
            test.pre.sql
            stderr.err
```

## 5. 입력 파싱 설계

### 5.1 `.ts` 파싱
- 기준 경로: 현재 `.ts` 파일 디렉터리
- 규칙:
  - 빈 줄 무시
  - `#` 시작 라인 주석
  - 상대경로를 `realpath` 정규화
  - repo root 바깥이면 `ERROR(path_outside_root)`
- 중첩:
  - DFS pre-order
  - cycle 감지 시 해당 항목 `ERROR(cycle_include)`
  - 동일 SQL 중복은 first-win

### 5.2 SQL 지시어 파싱
- 지시어 인식 조건: 라인 1열 `--+`
- 지원:
  - `--+SYSTEM <cmd>;`
  - `--+SET_ENV KEY=VALUE;`
  - `--+UNSET_ENV KEY;`
  - `--+SKIP BEGIN;` / `--+SKIP END;`
- 파서 상태:
  - `env_map`: directive 환경 변수 맵
  - `skip_mode`: SKIP 블록 내부 여부
- SQL 파일 경계 시 `env_map` 초기화

### 5.3 Directive 처리 결과
각 SQL 파일은 다음 3개 결과를 생성한다.
1. `directive_actions`: 실행할 SYSTEM/ENV 조작 목록
2. `preprocessed_sql_lines`: `is`로 넘길 SQL 라인
3. `parse_diagnostics`: parse 오류 정보

## 6. 실행 설계

### 6.1 사전 점검
- 필수 명령 확인: `is`, `clean`, `server`, `diff`
- 출력 디렉터리 쓰기 가능 여부 확인
- 옵션 정합성 확인:
  - `--fatal-recover-max >= 1`
  - `--ui`와 `--open-viewdiff` 조합
- 포트 헬스체크 설정 확인:
  - `ALTIBASE_PORT_NO` 정수 파싱 (기본값 17730 허용)
  - `localhost:<ALTIBASE_PORT_NO>` TCP connect 타임아웃 기본 1초

### 6.2 케이스 계획 생성
- single 모드:
  - 단계: `[test.sql]`
- triple 모드 (`.../test.sql` 기준):
  - 단계: `[init.sql?] -> [test.sql] -> [destroy.sql?]`
  - 비교 기준 파일은 항상 `test.sql`

### 6.3 케이스 실행 알고리즘

```text
for case in cases:
  run case phases in order
  for phase_sql in phases:
    parse directives
    run directive actions sequentially
    execute preprocessed SQL via is
    collect stdout/stderr/exit_code
    run port healthcheck(localhost:ALTIBASE_PORT_NO)
    if port_closed:
      classify current case as FATAL(server_port_closed)
      go fatal handling

  compare test.out vs test.lst
  classify status
  if status == FATAL:
    if --fatal-recover:
      recover(clean -> server start)
      if recover_ok: continue next case
      else: stop with code 3
    else:
      stop with code 2
```

- `destroy.sql`은 항상 시도(best-effort)
- `--fatal-recover`에서도 방금 FATAL 케이스는 재실행하지 않음

### 6.4 포트 헬스체크
- 체크 시점: 각 SQL(phase) 실행 직후
- 방법: `localhost:ALTIBASE_PORT_NO`에 TCP connect
- 실패 시:
  - 방금 실행한 케이스를 `FATAL(server_port_closed)`로 분류
  - 기본은 즉시 중단, `--fatal-recover`면 복구 절차 수행

### 6.5 SYSTEM/ENV 스코프
- `SET_ENV`는 같은 SQL 파일 내 이후 `SYSTEM`에 적용
- `UNSET_ENV` 전까지 유지
- 다음 SQL 파일 시작 시 초기화

## 7. 비교/판정 설계

### 7.1 정규화
- `CRLF -> LF`
- trailing spaces 제거
- 파일 말미 빈 줄 정리
- `--raw-diff`면 정규화 생략

### 7.2 2단계 비교
1. strict 비교
2. strict 불일치 시 order-insensitive 비교
   - 초기 버전 지원 범위:
     - 단일 SELECT 결과 1개
     - 동일 컬럼 수의 행으로 파싱 가능한 표 형식(IS 기본 출력 형식)
     - 멀티라인 LOB/CLOB 출력은 미지원
   - 지원 범위에서 파싱 가능하면 행 멀티셋 비교
   - 값 동일/순서만 다르면 `ORDER(ordering_mismatch)`
   - 파싱 불가 시 ORDER 판정을 생략하고 `FAIL(content_mismatch)` 유지

### 7.3 상태 및 우선순위
- 상태: `PASS`, `ORDER`, `FAIL`, `ERROR`, `FATAL`
- 우선순위: `FATAL > ERROR > ORDER > FAIL > PASS`

### 7.4 FATAL 판정
- 분류 조건:
  - 접속 실패/연결 종료/서버 다운
  - SQL 실행 직후 `ALTIBASE_PORT_NO` 포트가 닫힘
  - 서버 프로세스 비정상 종료 확인
- 기본 패턴(`fatal_patterns`):
  - `ERR-50032`
  - `Client unable to establish connection`
  - `Failed to invoke the connect() system function`
  - `ISQL_CONNECTION = TCP`

## 8. FATAL 복구 설계

### 8.1 기본 동작
- `FATAL` 발생 시 즉시 중단
- 종료코드: `2`

### 8.2 `--fatal-recover`
- 복구 절차:
  1. FATAL 케이스 기록
  2. `clean`
  3. `server start`
  4. 성공 시 다음 케이스 진행
- 복구 실패:
  - `fatal_recovery_failed`
  - 종료코드: `3`
- 시도 횟수 제한:
  - `--fatal-recover-max` (기본 1)
- 복구의 `clean`은 안전 복구 예외 경로로 허용

## 9. CLI/종료코드 설계

### 9.1 altitest 옵션
- 실행/환경:
  - `--server-mode <start-once|restart-once|per-case|none>`
  - `--clean-mode <none|before-suite|before-each>`
  - `--allow-clean`
  - `--timeout-sec <n>`
- 비교/판정:
  - `--order-check <auto|off>`
  - `--order-is-pass`
  - `--raw-diff`
- FATAL 처리:
  - `--fatal-recover`
  - `--fatal-recover-max <n>`
- 편의:
  - `--case <index|path>`
  - `--open-viewdiff`
  - `--ui <cli|java>`
  - `--diff-tool <cmd>`
  - `--accept-out` (FAIL 케이스만 `.out -> .lst` 반영)
  - `--accept-missing-only`
  - `--yes`
  - `--non-interactive`
  - `--ai-report`

### 9.2 종료코드
- `0`: PASS만 존재 (또는 `--order-is-pass` + PASS/ORDER)
- `1`: ORDER/FAIL/ERROR 존재
- `2`: FATAL로 중단
- `3`: FATAL 복구 실패

## 10. 리포팅 설계

### 10.1 콘솔 출력
- 고정 상태 컬럼
- 긴 경로는 중간 생략

예시:
```text
sql/task1/a.sql ................................................... PASS
sql/task1/b.sql ................................................... ORDER
sql/task1/c.sql ................................................... FATAL
```

### 10.2 run.json 필드
- 메타:
  - `schema_version`, `run_id`, `suite`, `started_at`, `ended_at`
- 옵션:
  - `server_mode`, `clean_mode`, `fatal_recover`, `fatal_recover_max`, `diff_tool`
- 요약:
  - `total`, `executed`, `not_run`, `pass`, `order`, `fail`, `error`, `fatal`
- 케이스 결과:
  - `index`, `sql`, `mode`, `phase_sql`, `lst`, `out`, `err`
  - `status`, `reason`, `exit_code`, `duration_ms`
  - `rerun_cmd`, `artifacts`, `analysis_hint`
- 런 상태:
  - `run_state.stopped_by_fatal`
  - `run_state.stopped_case_index`

### 10.3 ai-report
- `triage.json`: 문제 케이스 요약 + 자동 분류 힌트
- `summary.txt`: 사람이 바로 읽을 요약
- `cases/<n>/`: diff/정규화/전처리 SQL

### 10.4 AI 협업 입력 최소 세트
에이전트에게 분석 요청 시 최소 필요 파일:
1. 실행 명령
2. `out/last_run.json` 또는 `out/runs/<run_id>/run.json`
3. 필요 시 `triage.json`

### 10.5 UI 없는 자동 분석 경로
- 목적: `viewdiff` UI 없이 에이전트가 결과를 판별할 수 있어야 한다.
- 권장 실행:
  - `altitest <suite.ts> --non-interactive --ai-report`
- 에이전트 확인 순서:
  1. `run.json`에서 `summary`와 `results[*].status/reason` 확인
  2. `triage.json`에서 문제 케이스 우선순위 확인
  3. 필요 시 `cases/<index>/diff.txt`, `*.norm`, `*.err`로 상세 원인 확인

## 11. viewdiff 설계

### 11.1 공통 백엔드
- 목록 소스: `run.json`
- 표시 대상: `ORDER`, `FAIL`, `ERROR`, `FATAL`
- 도구 우선순위:
  - CLI 지정 > `ALTI_DIFF_TOOL` > `meld` > `kdiff3` > `code --diff`
- GUI diff 도구 없으면 텍스트 unified diff fallback

### 11.2 UI 모드
- CLI 모드:
  - 번호 목록 출력
  - 번호 선택
- Java 모드(`--ui java`):
  - 테이블 + 더블클릭
  - 버튼: `Open Diff`, `Accept OUT -> LST`, `Refresh`

`Accept OUT -> LST` 버튼 동작:
1. FAIL 항목을 마우스로 선택
2. 버튼 클릭
3. 확인 프롬프트(`--yes`가 없을 때만)
4. 기존 `.lst`를 `.lst.bak.<timestamp>`로 백업
5. 선택 항목의 `.out` 내용을 `.lst`로 덮어쓰기
6. 목록/상태 갱신(`Refresh` 자동 호출)

### 11.3 특수 항목 처리
- `missing_lst`: `.out` 단독 열람 + update 제공
- `FATAL`: `.err`/실행 로그 우선 노출
- `Accept OUT -> LST` 버튼은 기본적으로 `FAIL` 선택 항목에 활성화된다.

## 12. LST 갱신 설계
- `--accept-out`: FAIL 대상 갱신
- `--accept-missing-only`: missing_lst만 생성
- 기존 `.lst`는 `.bak.<timestamp>` 백업
- `--yes` 없으면 확인 프롬프트

## 13. 실패 사유 코드
- 상태 코드:
  - `PASS`, `ORDER`, `FAIL`, `ERROR`, `FATAL`
- reason 코드:
  - `ordering_mismatch`
  - `content_mismatch`
  - `missing_lst`
  - `exec_failed`
  - `server_disconnected`
  - `server_port_closed`
  - `fatal_recovery_failed`
  - `timeout`
  - `cycle_include`
  - `path_outside_root`
  - `parse_error`
  - `unknown_directive`
  - `internal_error`

## 14. 테스트 전략

### 14.1 단위 테스트
- suite parser: 중첩/순환/경로경계
- directive parser: SET/UNSET/SKIP 문법 및 스코프
- classifier: 우선순위/FATAL 분류/ORDER 분류

### 14.2 통합 테스트
- single/triple 실행
- FATAL 중단/복구 시나리오
- viewdiff 목록/선택
- 로컬 모킹 스모크: `tests/manual/run_smoke.sh`
  - `tests/manual/fakebin`으로 `is/clean/server` 모킹
  - PASS/ORDER/FAIL/ERROR/FATAL/복구/파서 오류 시나리오 자동 검증

### 14.3 회귀 테스트
- 샘플 suite 고정
- run.json 스키마 호환성 검증

## 15. 구현 단계 제안
1. `altitest` 최소 실행(PASS/FAIL/ERROR)
2. directive 파서 + single/triple
3. ORDER 판정
4. FATAL 분류 + 복구
5. viewdiff CLI
6. viewdiff Java UI
7. ai-report
