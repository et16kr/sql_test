--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_snapshot_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh snapshot_restore_old_history_ok;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh snapshot_restore_old_history_missing_key_fail;
-- Test Purpose: Remove the required old key history while the older snapshot is active.
-- Checks: Startup failure is observed and the restored environment still reads the old snapshot.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN (SELECT COUNT(*) FROM TDE_SQLT_T) = 2 AND (SELECT COUNT(*) FROM TDE2_ENC_T) = 2 AND (SELECT COUNT(*) FROM TDE_TMP_NEW_ENC_T) = 1 THEN 1 ELSE 0 END AS PASS_ROWS FROM DUAL;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ZERO_ACTIVE_REFCOUNT FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1 AND REFERENCED_TABLESPACE_COUNT = 0;