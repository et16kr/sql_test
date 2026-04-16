--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_snapshot_fixture;
-- Test Purpose: Capture pre/post-rotate checkpoint-image snapshots and leave the server on the newer key history.
-- Checks: Another rotate occurred and the active key is not yet referenced by any tablespace.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 4 THEN 1 ELSE 0 END AS PASS_KEY_COUNT FROM V$TDE_MASTER_KEYS;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ZERO_REFCOUNT FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1 AND REFERENCED_TABLESPACE_COUNT = 0;