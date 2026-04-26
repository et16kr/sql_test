--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_base_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh log_replication_reader_smoke;
-- Test Purpose: Smoke insert/update/delete log shapes consumed by replication-oriented log readers.
-- Checks: Final row state is SQL-visible and row payload markers are absent from recovery log files.
-- Manual reference:
--   /home/et16/work/altidev4/docs/manuals/altibase/trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS PASS_DELETE_ROW
  FROM TDE_SQLT_T
 WHERE I = 1104;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_UPDATE_ROW
  FROM TDE_SQLT_T
 WHERE I = 1105
   AND V = 'TDE11_RP_UPDATE_B';
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ENCRYPTED_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE_SQLT_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID > 0;
