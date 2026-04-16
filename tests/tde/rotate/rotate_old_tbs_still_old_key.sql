--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_rotate_twice_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_new_encrypted_fixture;
-- Test Purpose: Verify existing encrypted tablespaces do not follow the active key automatically.
-- Checks: Base and extended encrypted tablespaces stay on the old key while the new fixture uses the active key.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_OLD_KEY_TBS FROM V$TABLESPACES WHERE NAME IN ('TDE_SQLT_TBS', 'TDE2_ENC_TBS') AND MASTER_KEY_ID <> (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_ACTIVE_KEY_TBS FROM V$TABLESPACES WHERE NAME = 'TDE_TMP_NEW_ENC_TBS' AND MASTER_KEY_ID = (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);