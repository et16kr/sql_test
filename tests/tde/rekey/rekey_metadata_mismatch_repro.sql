-- Reference: doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
--+TIMEOUT_SEC 900;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh repro_rekey_metadata_mismatch;
-- Test Purpose: Reject REKEY when on-disk TBS metadata no longer matches
--   the runtime TDE metadata loaded at startup.
-- Checks: After corrupting only the on-disk wrapped TBS key post-startup,
--   REKEY is rejected, the operation view reports FAILED, and the tablespace
--   remains readable after best-effort ONLINE recovery.
-- Note: This standalone repro/regression case is intentionally excluded
--   from tde.ts.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_REPRO_ROWS
  FROM TDE_REPRO_T;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_REPRO_TBS
  FROM V$TDE_TABLESPACES
 WHERE NAME = 'TDE_REPRO_TBS'
   AND IS_ENCRYPTED = 1
   AND MASTER_KEY_ID > 0;
SELECT CASE WHEN COUNT(*) = 1 THEN 1 ELSE 0 END AS PASS_REPRO_OPERATION
  FROM V$TDE_OPERATION
 WHERE OPERATION = 'REKEY'
   AND STATE = 'FAILED';
--+SYSTEM bash ./tests/tde/bin/tde_case.sh finalize_environment;
