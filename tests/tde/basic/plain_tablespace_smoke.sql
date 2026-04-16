--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_temp_plain_fixture;
-- Test Purpose: Create a plain MRDB tablespace while TDE is enabled.
-- Checks: Plain tablespace metadata and row values are normal.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_PLAIN_ROWS FROM TDE_TMP_PLAIN_T;
SELECT CASE WHEN SUM(CASE WHEN V IN ('plain-one', 'plain-two') THEN 1 ELSE 0 END) = 2 THEN 1 ELSE 0 END AS PASS_PLAIN_VALUES FROM TDE_TMP_PLAIN_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_PLAIN_TBS FROM V$TABLESPACES WHERE NAME = 'TDE_TMP_PLAIN_TBS' AND IS_ENCRYPTED = 0;