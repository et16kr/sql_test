--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_rotate_once_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh negative_rotated_key_history;
-- Test Purpose: Verify rotated key history remains required until older encrypted tablespaces are rekeyed.
-- Checks: Startup failure is observed and the restored environment returns to normal.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ENC_COUNT FROM TDE2_ENC_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_OLD_KEY_RETAINED
  FROM V$TABLESPACES
 WHERE NAME = 'TDE2_ENC_TBS'
   AND MASTER_KEY_ID <> (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);