-- Test Purpose: Verify FIRST_VALUE and DENSE_RANK window semantics.
-- Checks: Window frame/ranking values match expected results.
-- Disk sort temp coverage 08: window FIRST_VALUE + DENSE_RANK with packed rows
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV08;
--+SKIP_END;

CREATE TABLE DST_COV08
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    V1       VARCHAR(3200),
    V2       VARCHAR(3200),
    V3       VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV08
SELECT LEVEL,
       MOD(LEVEL, 23),
       RPAD('L' || TO_CHAR(LEVEL), 3200, 'L'),
       RPAD('M' || TO_CHAR(MOD(LEVEL, 210)), 3200, 'M'),
       RPAD('N' || TO_CHAR(MOD(LEVEL, 70)), 3200, 'N')
  FROM DUAL
CONNECT BY LEVEL <= 1700;

SELECT ID, GRP_ID, DRANK
  FROM (
        SELECT /*+ TEMP_TBS_DISK */
               ID,
               GRP_ID,
               FIRST_VALUE(V1) OVER (PARTITION BY GRP_ID ORDER BY V2 DESC, ID) AS FV,
               DENSE_RANK() OVER (PARTITION BY GRP_ID ORDER BY V2 DESC, ID) AS DRANK
          FROM DST_COV08
       ) W
 WHERE DRANK <= 2
 ORDER BY GRP_ID, DRANK, ID;

DROP TABLE DST_COV08;
