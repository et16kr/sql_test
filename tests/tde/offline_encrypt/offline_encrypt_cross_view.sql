--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_extended_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh encrypt_tablespace TDE2_PLAIN_TBS;
-- Test Purpose: Cross-check general and dedicated views after OFFLINE ENCRYPT.
-- Checks: The encrypted tablespace and active-key reference count agree across views.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_GENERAL_ENC FROM V$TABLESPACES WHERE NAME = 'TDE2_PLAIN_TBS' AND IS_ENCRYPTED = 1;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_DEDICATED_ENC FROM V$TDE_TABLESPACES WHERE NAME = 'TDE2_PLAIN_TBS' AND IS_ENCRYPTED = 1;
SELECT CASE WHEN (SELECT REFERENCED_TABLESPACE_COUNT FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1) = 3 THEN 1 ELSE 0 END AS PASS_ACTIVE_REFCOUNT FROM DUAL;