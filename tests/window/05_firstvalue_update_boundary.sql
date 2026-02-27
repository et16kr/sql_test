-- Test Purpose: Regression test for FIRST_VALUE update-column handling in disk temp window sort.
-- Checks: No internal error on mixed payload lengths (14/15/3200) and stable ranking output.
-- Disk sort temp coverage WN05: FIRST_VALUE + DENSE_RANK update path with boundary payload lengths
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV_WN05;
--+SKIP_END;

CREATE TABLE DST_COV_WN05
(
    ID         INTEGER,
    GRP_ID     INTEGER,
    V_PAYLOAD  VARCHAR(3200),
    V_SORT     VARCHAR(3200),
    V_PAD      VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_WN05
SELECT LEVEL,
       MOD(LEVEL, 29),
       CASE MOD(LEVEL, 3)
            WHEN 0 THEN RPAD('A' || TO_CHAR(LEVEL), 14, 'A')
            WHEN 1 THEN RPAD('B' || TO_CHAR(LEVEL), 15, 'B')
            ELSE RPAD('C' || TO_CHAR(LEVEL), 3200, 'C')
       END,
       RPAD('S' || TO_CHAR(MOD(LEVEL, 240)), 3200, 'S'),
       RPAD('P' || TO_CHAR(MOD(LEVEL, 90)), 3200, 'P')
  FROM DUAL
CONNECT BY LEVEL <= 2200;

SELECT GRP_ID,
       MIN(FV_LEN) AS MIN_FV_LEN,
       MAX(FV_LEN) AS MAX_FV_LEN,
       COUNT(*) AS CNT
  FROM (
        SELECT GRP_ID,
               DENSE_RANK() OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID) AS DRANK,
               LENGTH(FIRST_VALUE(V_PAYLOAD) OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID)) AS FV_LEN
          FROM DST_COV_WN05
       ) W
 WHERE DRANK <= 2
 GROUP BY GRP_ID
 ORDER BY GRP_ID;

SELECT ID,
       GRP_ID,
       LENGTH(FV) AS FV_LEN,
       DRANK
  FROM (
        SELECT /*+ TEMP_TBS_DISK */
               ID,
               GRP_ID,
               FIRST_VALUE(V_PAYLOAD) OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID) AS FV,
               DENSE_RANK() OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID) AS DRANK
          FROM DST_COV_WN05
       ) W
 WHERE GRP_ID IN (0, 1, 2, 3)
   AND DRANK <= 2
 ORDER BY GRP_ID, DRANK, ID;

DROP TABLE DST_COV_WN05;
