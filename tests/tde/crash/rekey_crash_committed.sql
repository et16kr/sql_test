--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_rekey_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh crash_rekey_committed;
-- Test Purpose: Recover a REKEY crash after the COMMITTED journal is persisted.
-- Checks: Startup completes the committed journal and preserves the active master key.
-- Manual reference:
--   /home/et16/work/altidev4/docs/manuals/altibase/trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ROWS FROM TDE2_ENC_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_REKEYED
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE2_ENC_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID = (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_OPERATION_IDLE
  FROM V$TDE_OPERATION
 WHERE OPERATION = 'NONE'
   AND STATE = 'IDLE'
   AND TARGET_MASTER_KEY_ID = 0;
