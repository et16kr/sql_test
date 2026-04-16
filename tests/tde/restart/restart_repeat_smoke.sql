--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh restart_repeat_smoke;
-- Test Purpose: Restart the server twice and re-read the base encrypted fixture.
-- Checks: The encrypted rows and metadata survive repeated restart.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_BASE_ROWS FROM TDE_SQLT_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ENC_TBS FROM V$TABLESPACES WHERE NAME = 'TDE_SQLT_TBS' AND IS_ENCRYPTED = 1;