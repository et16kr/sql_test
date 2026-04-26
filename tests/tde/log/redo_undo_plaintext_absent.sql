--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh log_redo_undo_plaintext_absent;
-- Test Purpose: Verify encrypted tablespace redo/undo memory log payloads do not expose row plaintext.
-- Checks: SQL-visible committed and rolled-back rows remain correct while log files contain no deterministic markers.
-- Manual reference:
--   /home/et16/work/altidev4/docs/manuals/altibase/trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_REDO_ROW
  FROM TDE_SQLT_T
 WHERE I = 1101
   AND V = 'TDE11_REDO_MARKER';
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_UNDO_ROW
  FROM TDE_SQLT_T
 WHERE I = 1102
   AND V = 'TDE11_UNDO_BASE';
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ENCRYPTED_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE_SQLT_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID > 0;
