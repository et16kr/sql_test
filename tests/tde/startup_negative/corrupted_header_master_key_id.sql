--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh negative_corrupted_header_master_key_id;
-- Test Purpose: Corrupt the checkpoint image header master key id.
-- Checks: Startup failure is observed and the recovered environment can read the base encrypted tablespace.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_BASE_ROWS FROM TDE_SQLT_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_BASE_TBS FROM V$TABLESPACES WHERE NAME = 'TDE_SQLT_TBS' AND IS_ENCRYPTED = 1;