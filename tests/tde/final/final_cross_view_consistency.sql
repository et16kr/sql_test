--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_all_plain_fixture;
-- Test Purpose: Cross-check the final all-plain state after every decrypt path has completed.
-- Checks: All tracked MRDB tablespaces are plain and no master key keeps a referenced tablespace count.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 6 THEN 1 ELSE 0 END AS PASS_ALL_PLAIN FROM V$TABLESPACES WHERE NAME IN ('TDE_SQLT_TBS', 'TDE2_PLAIN_TBS', 'TDE2_ENC_TBS', 'TDE_TMP_PLAIN_TBS', 'TDE_TMP_NEW_ENC_TBS', 'TDE_TMP_EMPTY_PLAIN_TBS') AND IS_ENCRYPTED = 0 AND MASTER_KEY_ID = 0;
SELECT CASE WHEN COUNT(*) = 6 THEN 1 ELSE 0 END AS PASS_ALL_PLAIN_TDE FROM V$TDE_TABLESPACES WHERE NAME IN ('TDE_SQLT_TBS', 'TDE2_PLAIN_TBS', 'TDE2_ENC_TBS', 'TDE_TMP_PLAIN_TBS', 'TDE_TMP_NEW_ENC_TBS', 'TDE_TMP_EMPTY_PLAIN_TBS') AND IS_ENCRYPTED = 0 AND MASTER_KEY_ID = 0;
SELECT CASE WHEN (SELECT SUM(REFERENCED_TABLESPACE_COUNT) FROM V$TDE_MASTER_KEYS) = 0 THEN 1 ELSE 0 END AS PASS_ZERO_REFCOUNT FROM DUAL;