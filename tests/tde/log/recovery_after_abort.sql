--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh log_recovery_after_abort;
-- Test Purpose: Verify startup redo recovery can replay encrypted memory log payloads after shutdown abort.
-- Checks: The committed row survives recovery and its payload marker is absent from log files.
-- Manual reference:
--   /home/et16/work/altidev4/docs/manuals/altibase/trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_RECOVERED_ROW
  FROM TDE_SQLT_T
 WHERE I = 1103
   AND V = 'TDE11_RECOVERY_MARKER';
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ENCRYPTED_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE_SQLT_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID > 0;
