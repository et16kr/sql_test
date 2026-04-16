--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_all_plain_fixture;
-- Test Purpose: Decrypt every known encrypted MRDB tablespace and restart.
-- Checks: All tracked MRDB tablespaces are plain and their data remains readable.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 6 THEN 1 ELSE 0 END AS PASS_ALL_PLAIN FROM V$TDE_TABLESPACES WHERE NAME IN ('TDE_SQLT_TBS', 'TDE2_PLAIN_TBS', 'TDE2_ENC_TBS', 'TDE_TMP_PLAIN_TBS', 'TDE_TMP_NEW_ENC_TBS', 'TDE_TMP_EMPTY_PLAIN_TBS') AND IS_ENCRYPTED = 0 AND MASTER_KEY_ID = 0;
SELECT CASE WHEN (SELECT COUNT(*) FROM TDE_SQLT_T) = 2 AND (SELECT COUNT(*) FROM TDE2_ENC_T) = 2 AND (SELECT COUNT(*) FROM TDE_TMP_NEW_ENC_T) = 1 AND (SELECT COUNT(*) FROM TDE_TMP_PLAIN_T) = 2 THEN 1 ELSE 0 END AS PASS_ROWS FROM DUAL;