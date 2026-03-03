-- Test Purpose: Verify NO_MERGE view materialization path correctness.
-- Checks: Materialized view row count and filtered count are correct.
-- Disk sort temp coverage 14: NO_MERGE view materialization + full scan cursor
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV14_BASE;
--+SKIP END;

CREATE TABLE DST_COV14_BASE
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    PAD1     VARCHAR(3200),
    PAD2     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV14_BASE
SELECT LEVEL,
       MOD(LEVEL, 61),
       RPAD('V' || TO_CHAR(LEVEL), 3200, 'V'),
       RPAD('W' || TO_CHAR(MOD(LEVEL, 700)), 3200, 'W')
  FROM DUAL
CONNECT BY LEVEL <= 2100;

ALTER SESSION SET EXPLAIN PLAN = ONLY;
SELECT /*+ TEMP_TBS_DISK NO_MERGE(V) */ COUNT(*)
  FROM (
        SELECT ID, GRP_ID, PAD1
          FROM DST_COV14_BASE
         ORDER BY GRP_ID, ID
       ) V
 WHERE V.GRP_ID BETWEEN 5 AND 12;
ALTER SESSION SET EXPLAIN PLAN = OFF;

SELECT /*+ TEMP_TBS_DISK NO_MERGE(V) */ COUNT(*) AS FILTER_CNT
  FROM (
        SELECT ID, GRP_ID, PAD1
          FROM DST_COV14_BASE
         ORDER BY GRP_ID, ID
       ) V
 WHERE V.GRP_ID BETWEEN 5 AND 12;

DROP TABLE DST_COV14_BASE;
