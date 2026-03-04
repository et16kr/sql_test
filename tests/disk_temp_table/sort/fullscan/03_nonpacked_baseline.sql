-- Test Purpose: Provide non-packed baseline behavior for full scan path.
-- Checks: Baseline count/result stays unchanged versus packed-row coverage changes.
-- Disk sort temp coverage 03: small fixed-width row (non packed path baseline)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV03;
--+SKIP END;

CREATE TABLE DST_COV03
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    C1       CHAR(8),
    C2       CHAR(8),
    N1       NUMERIC(10)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV03
SELECT LEVEL,
       MOD(LEVEL, 31),
       LPAD(TO_CHAR(MOD(LEVEL, 100)), 8, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 77)), 8, '0'),
       MOD(LEVEL * 13, 10000)
  FROM DUAL
CONNECT BY LEVEL <= 1800;

SELECT /*+ TEMP_TBS_DISK */ ID, GRP_ID, N1
  FROM DST_COV03
 ORDER BY C1, C2, N1 DESC
 LIMIT 40;

SELECT CASE WHEN COUNT(*) = 1800 THEN 1 ELSE 0 END AS PASS_COUNT
  FROM DST_COV03;

DROP TABLE DST_COV03;
