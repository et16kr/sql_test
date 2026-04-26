--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_offline_decrypt_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh crash_offline_decrypt_target_synced;
-- Test Purpose: Recover an offline decrypt crash after the plain target file is synced.
-- Checks: Startup rolls back to the encrypted source image and data remains readable.
-- Manual reference:
--   /home/et16/work/altidev4/docs/manuals/altibase/trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ROWS FROM TDE2_PLAIN_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_STILL_ENCRYPTED
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE2_PLAIN_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID > 0;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_OPERATION_IDLE
  FROM V$TDE_OPERATION
 WHERE OPERATION = 'NONE'
   AND STATE = 'IDLE'
   AND TARGET_MASTER_KEY_ID = 0;
