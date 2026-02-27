-- Test Purpose: Verify ORDER BY with NULL values keeps expected null ordering semantics.
-- Checks: NULL placement and sorted sequence are correct.
-- Disk sort temp coverage FS07: NULLS FIRST/LAST ordered full scan
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV_FS07;
--+SKIP_END;

CREATE TABLE DST_COV_FS07
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    K1       VARCHAR(64),
    K2       VARCHAR(64),
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_FS07
SELECT LEVEL,
       MOD(LEVEL, 41),
       CASE WHEN MOD(LEVEL, 11) = 0 THEN NULL
            ELSE 'K' || LPAD(TO_CHAR(MOD(LEVEL, 300)), 4, '0') END,
       CASE WHEN MOD(LEVEL, 13) = 0 THEN NULL
            ELSE 'S' || LPAD(TO_CHAR(MOD(LEVEL, 500)), 4, '0') END,
       RPAD('N' || TO_CHAR(LEVEL), 3200, 'N')
  FROM DUAL
CONNECT BY LEVEL <= 2100;

SELECT /*+ TEMP_TBS_DISK */ ID, K1, K2
  FROM DST_COV_FS07
 ORDER BY K1 NULLS FIRST, K2 NULLS LAST, ID
 LIMIT 80;

SELECT CASE WHEN COUNT(*) = 2100 THEN 1 ELSE 0 END AS PASS_COUNT
  FROM DST_COV_FS07;

DROP TABLE DST_COV_FS07;
