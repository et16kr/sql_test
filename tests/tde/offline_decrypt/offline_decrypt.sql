--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_offline_decrypt_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh decrypt_tablespace TDE2_PLAIN_TBS;
-- Test Purpose: Decrypt an existing encrypted MRDB tablespace while offline.
-- Checks: The tablespace returns to plain state and the operation view reports success.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_PLAIN_COUNT FROM TDE2_PLAIN_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_PLAIN_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE2_PLAIN_TBS'
   AND IS_ENCRYPTED = 0
   AND MASTER_KEY_ID = 0;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_OPERATION
  FROM V$TDE_OPERATION
 WHERE OPERATION = 'OFFLINE_DECRYPT'
   AND STATE = 'SUCCESS';