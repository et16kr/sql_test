--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh prepare_offline_decrypt_fixture;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh decrypt_tablespace TDE2_PLAIN_TBS;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh encrypt_tablespace TDE2_PLAIN_TBS;
-- Test Purpose: Re-encrypt the tablespace after OFFLINE DECRYPT.
-- Checks: The tablespace returns to encrypted state on the latest active key.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_ROWS FROM TDE2_PLAIN_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_REENCRYPTED FROM V$TDE_TABLESPACES WHERE NAME = 'TDE2_PLAIN_TBS' AND IS_ENCRYPTED = 1 AND MASTER_KEY_ID = (SELECT KEY_ID FROM V$TDE_MASTER_KEYS WHERE IS_ACTIVE = 1);