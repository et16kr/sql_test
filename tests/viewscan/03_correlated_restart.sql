-- Test Purpose: Verify correlated restart behavior in repeated view/subquery execution.
-- Checks: Repeated correlation evaluation returns stable, correct results.
-- Disk sort temp coverage VS03: correlated subquery over NO_MERGE view (restart path)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV_VS03_BASE;
--+SKIP END;

CREATE TABLE DST_COV_VS03_BASE
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_VS03_BASE
SELECT LEVEL,
       MOD(LEVEL, 57),
       RPAD('V' || TO_CHAR(MOD(LEVEL, 300)), 3200, 'V')
  FROM DUAL
CONNECT BY LEVEL <= 1600;

SELECT A.ID,
       (
        SELECT /*+ TEMP_TBS_DISK NO_MERGE(V) */ COUNT(*)
          FROM (
                SELECT ID, GRP_ID, PAD1
                  FROM DST_COV_VS03_BASE
                 ORDER BY GRP_ID, ID
               ) V
         WHERE V.GRP_ID = A.GRP_ID
           AND V.ID <= A.ID
       ) AS IN_GRP_PREFIX_CNT
  FROM DST_COV_VS03_BASE A
 WHERE A.ID <= 40
 ORDER BY A.ID;

DROP TABLE DST_COV_VS03_BASE;
