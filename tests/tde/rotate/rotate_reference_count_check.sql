--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_rotate_twice_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_new_encrypted_fixture;
-- Test Purpose: Check referenced tablespace counts after creating a new encrypted tablespace under the latest key.
-- Checks: Active-key and total-key reference counts match the visible tablespace state.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN (SELECT REFERENCED_TABLESPACE_COUNT FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1) = 1 THEN 1 ELSE 0 END AS PASS_ACTIVE_REFCOUNT FROM DUAL;
SELECT CASE WHEN (SELECT SUM(REFERENCED_TABLESPACE_COUNT) FROM V$TDE_MASTER_KEYS) = 3 THEN 1 ELSE 0 END AS PASS_TOTAL_REFCOUNT FROM DUAL;