--+TIMEOUT_SEC 600;
-- Test Purpose: Recheck the base encrypted table rows and values.
-- Checks: The bootstrap fixture still contains the expected MRDB data.
-- Manual reference:
--   doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
SELECT CASE WHEN COUNT(*) = 2 THEN 1 ELSE 0 END AS PASS_BASE_ROWS FROM TDE_SQLT_T;
SELECT CASE WHEN MIN(I) = 1 AND MAX(I) = 2 THEN 1 ELSE 0 END AS PASS_BASE_RANGE FROM TDE_SQLT_T;
SELECT CASE WHEN SUM(CASE WHEN V IN ('alpha', 'beta') THEN 1 ELSE 0 END) = 2 THEN 1 ELSE 0 END AS PASS_BASE_VALUES FROM TDE_SQLT_T;