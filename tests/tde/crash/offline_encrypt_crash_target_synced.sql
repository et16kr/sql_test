--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_extended_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh crash_offline_encrypt_target_synced;
-- Test Purpose: Recover an offline encrypt crash after the target file is synced.
-- Checks: Startup hides the completed target image until the operation can be retried.
-- Manual reference:
--   /home/et16/work/altidev4/docs/manuals/altibase/trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ROWS FROM TDE2_PLAIN_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_STILL_PLAIN
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE2_PLAIN_TBS'
   AND IS_ENCRYPTED = 0
   AND MASTER_KEY_ID = 0;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_OPERATION_IDLE
  FROM V$TDE_OPERATION
 WHERE OPERATION = 'NONE'
   AND STATE = 'IDLE'
   AND TARGET_MASTER_KEY_ID = 0;
