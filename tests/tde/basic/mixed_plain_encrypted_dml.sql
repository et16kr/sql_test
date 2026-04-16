--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_temp_plain_fixture;
-- Test Purpose: Verify plain and encrypted MRDB fixtures remain usable together.
-- Checks: Both tables are readable and each tablespace keeps the expected encryption state.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN (SELECT COUNT(*) FROM TDE_SQLT_T) = 2 AND (SELECT COUNT(*) FROM TDE_TMP_PLAIN_T) = 2 THEN 1 ELSE 0 END AS PASS_MIXED_ROWS FROM DUAL;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ENC_STATE FROM V$TABLESPACES WHERE NAME = 'TDE_SQLT_TBS' AND IS_ENCRYPTED = 1;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_PLAIN_STATE FROM V$TABLESPACES WHERE NAME = 'TDE_TMP_PLAIN_TBS' AND IS_ENCRYPTED = 0;