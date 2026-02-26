-- Test Purpose: Verify re-sort behavior in window processing with mixed variable columns.
-- Checks: Reordered window results remain stable and correct.
-- Disk sort temp coverage WN04: multi-window with mixed order keys (resort/update path)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV_WN04;
--+SKIP END;

CREATE TABLE DST_COV_WN04
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    V1       VARCHAR(3200),
    V2       VARCHAR(3200),
    V3       VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_WN04
SELECT LEVEL,
       MOD(LEVEL, 37),
       RPAD('A' || TO_CHAR(MOD(LEVEL, 700)), 3200, 'A'),
       RPAD('B' || TO_CHAR(MOD(LEVEL, 300)), 3200, 'B'),
       RPAD('C' || TO_CHAR(MOD(LEVEL, 100)), 3200, 'C')
  FROM DUAL
CONNECT BY LEVEL <= 2600;

SELECT ID,
       GRP_ID,
       RN_ASC,
       RN_DESC,
       DR_DESC,
       PREV_ID
  FROM (
        SELECT /*+ TEMP_TBS_DISK */
               ID,
               GRP_ID,
               ROW_NUMBER() OVER (PARTITION BY GRP_ID ORDER BY V1, ID) AS RN_ASC,
               ROW_NUMBER() OVER (PARTITION BY GRP_ID ORDER BY V2 DESC, ID) AS RN_DESC,
               DENSE_RANK() OVER (PARTITION BY GRP_ID ORDER BY V2 DESC, ID) AS DR_DESC,
               LAG(ID, 1, 0) OVER (PARTITION BY GRP_ID ORDER BY V1, ID) AS PREV_ID
          FROM DST_COV_WN04
       ) W
 WHERE RN_ASC <= 2 OR RN_DESC <= 2
 ORDER BY GRP_ID, ID
 LIMIT 120;

SELECT CASE WHEN COUNT(*) = 2600 THEN 1 ELSE 0 END AS PASS_COUNT
  FROM DST_COV_WN04;

DROP TABLE DST_COV_WN04;
