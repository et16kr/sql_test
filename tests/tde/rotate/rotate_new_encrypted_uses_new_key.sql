--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_rotate_twice_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_new_encrypted_fixture;
-- Test Purpose: Create a new encrypted tablespace after the second rotate.
-- Checks: The new encrypted tablespace uses the current active master key.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_NEW_ROWS FROM TDE_TMP_NEW_ENC_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_NEW_KEY FROM V$TABLESPACES WHERE NAME = 'TDE_TMP_NEW_ENC_TBS' AND MASTER_KEY_ID = (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);