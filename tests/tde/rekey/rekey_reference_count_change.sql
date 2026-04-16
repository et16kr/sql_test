--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_rekey_reference_fixture;
-- Test Purpose: Check referenced tablespace counts after the final empty-tablespace REKEY.
-- Checks: The newest active key owns the empty tablespace only, while total reference counts stay consistent.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN (SELECT REFERENCED_TABLESPACE_COUNT FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1) = 1 THEN 1 ELSE 0 END AS PASS_ACTIVE_REFCOUNT FROM DUAL;
SELECT CASE WHEN (SELECT SUM(REFERENCED_TABLESPACE_COUNT) FROM V$TDE_MASTER_KEYS) = 5 THEN 1 ELSE 0 END AS PASS_TOTAL_REFCOUNT FROM DUAL;