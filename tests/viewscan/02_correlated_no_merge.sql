-- Test Purpose: Verify correlated subquery with NO_MERGE executes correctly.
-- Checks: Correlation filtering and result set are correct.
-- Disk sort temp coverage 15: correlated subquery over NO_MERGE ordered inline view
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV15_BASE;
--+SKIP_END;

CREATE TABLE DST_COV15_BASE
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV15_BASE
SELECT LEVEL,
       MOD(LEVEL, 47),
       RPAD('R' || TO_CHAR(MOD(LEVEL, 200)), 3200, 'R')
  FROM DUAL
CONNECT BY LEVEL <= 1300;

SELECT A.ID,
       (
        SELECT /*+ TEMP_TBS_DISK NO_MERGE(V2) */ MAX(V2.ID)
          FROM (
                SELECT ID, GRP_ID
                  FROM DST_COV15_BASE
                 ORDER BY GRP_ID, ID
               ) V2
         WHERE V2.GRP_ID = A.GRP_ID
       ) AS GRP_MAX_ID
  FROM DST_COV15_BASE A
 WHERE A.ID <= 40
 ORDER BY A.ID;

DROP TABLE DST_COV15_BASE;
