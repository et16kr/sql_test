--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh duplicate_keystore_rejected;
-- Test Purpose: Re-run CREATE KEYSTORE after bootstrap.
-- Checks: The server is recovered and the base encrypted tablespace remains readable.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_BASE_ROWS FROM TDE_SQLT_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_BASE_TBS FROM V$TABLESPACES WHERE NAME = 'TDE_SQLT_TBS' AND IS_ENCRYPTED = 1;