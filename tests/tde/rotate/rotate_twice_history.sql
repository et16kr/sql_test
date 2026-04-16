--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_rotate_twice_fixture;
-- Test Purpose: Rotate the master key a second time.
-- Checks: Key history grows while only one key remains active.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 3 THEN 1 ELSE 0 END AS PASS_KEY_COUNT FROM V$TDE_MASTER_KEYS;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ACTIVE_COUNT FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1;