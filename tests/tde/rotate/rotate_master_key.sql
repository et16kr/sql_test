--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_rotate_once_fixture;
-- Test Purpose: Rotate the master key without rekeying existing tablespaces.
-- Checks: Active key changes and the existing encrypted tablespace still points to the old key.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) >= 2 THEN 1 ELSE 0 END AS PASS_KEY_COUNT FROM V$TDE_MASTER_KEYS;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ACTIVE_COUNT FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_OLD_KEY_RETAINED
  FROM V$TABLESPACES
 WHERE NAME = 'TDE2_ENC_TBS'
   AND MASTER_KEY_ID <> (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ENC_COUNT FROM TDE2_ENC_T;