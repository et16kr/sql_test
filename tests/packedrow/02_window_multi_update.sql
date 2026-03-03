-- Test Purpose: Verify window query correctness after multi-column updates.
-- Checks: Updated values are reflected correctly in window-function results.
-- Disk sort temp coverage PR02: packed-row window multi-column update scenario
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV_PR02;
--+SKIP END;

CREATE TABLE DST_COV_PR02
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    K1       VARCHAR(64),
    V1       VARCHAR(3200),
    V2       VARCHAR(3200),
    V3       VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_PR02
SELECT LEVEL,
       MOD(LEVEL, 31),
       'K' || LPAD(TO_CHAR(MOD(LEVEL, 700)), 4, '0'),
       RPAD('P' || TO_CHAR(LEVEL), 3200, 'P'),
       RPAD('Q' || TO_CHAR(MOD(LEVEL, 240)), 3200, 'Q'),
       RPAD('R' || TO_CHAR(MOD(LEVEL, 90)), 3200, 'R')
  FROM DUAL
CONNECT BY LEVEL <= 1900;

SELECT ID, GRP_ID, RN, DR, PREV_ID
  FROM (
        SELECT /*+ TEMP_TBS_DISK */
               ID,
               GRP_ID,
               ROW_NUMBER() OVER (PARTITION BY GRP_ID ORDER BY V2 DESC, ID) AS RN,
               DENSE_RANK() OVER (PARTITION BY GRP_ID ORDER BY V2 DESC, ID) AS DR,
               LAG(ID, 1, 0) OVER (PARTITION BY GRP_ID ORDER BY V2 DESC, ID) AS PREV_ID
          FROM DST_COV_PR02
       ) W
 WHERE RN <= 3
 ORDER BY GRP_ID, RN, ID;

DROP TABLE DST_COV_PR02;
