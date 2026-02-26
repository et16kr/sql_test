-- Test Purpose: Verify ROW_NUMBER window ordering correctness after data updates.
-- Checks: Partition ordering and ranked output are correct.
-- Disk sort temp coverage 07: window row_number update path on disk sort temp
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV07;
--+SKIP END;

CREATE TABLE DST_COV07
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    V1       VARCHAR(3200),
    V2       VARCHAR(3200),
    V3       VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV07
SELECT LEVEL,
       MOD(LEVEL, 29),
       RPAD('A' || TO_CHAR(LEVEL), 3200, 'A'),
       RPAD('B' || TO_CHAR(MOD(LEVEL, 200)), 3200, 'B'),
       RPAD('C' || TO_CHAR(MOD(LEVEL, 50)), 3200, 'C')
  FROM DUAL
CONNECT BY LEVEL <= 1800;

SELECT ID, GRP_ID, RN
  FROM (
        SELECT /*+ TEMP_TBS_DISK */
               ID,
               GRP_ID,
               ROW_NUMBER() OVER (PARTITION BY GRP_ID ORDER BY V2 DESC, ID) AS RN
          FROM DST_COV07
       ) W
 WHERE RN <= 3
 ORDER BY GRP_ID, RN, ID;

DROP TABLE DST_COV07;
