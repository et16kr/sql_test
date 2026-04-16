--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh negative_invalid_keystore_missing_active;
-- Test Purpose: Remove ACTIVE_MASTER_KEY_ID from the keystore and verify startup rejection.
-- Checks: Startup failure is observed and the recovered environment can read the base encrypted tablespace.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_BASE_ROWS FROM TDE_SQLT_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_BASE_KEY FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1;