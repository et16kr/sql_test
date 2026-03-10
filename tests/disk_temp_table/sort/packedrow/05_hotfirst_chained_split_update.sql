-- Test Purpose: Validate packed + hot-first window update on chained rows with split update payload.
-- Checks:
--   1) FIRST_VALUE update column remains consistent with 9100-byte payload.
--   2) Chained cold columns (7000 + 7000) remain stable while update path runs.
--   3) Group-level summary remains deterministic.
-- Disk sort temp coverage PR05: packed chained update with hot-first moved update column + split write
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV_PR05;
--+SKIP END;

CREATE TABLE DST_COV_PR05
(
    ID        INTEGER,
    GRP_ID    INTEGER,
    K1        VARCHAR(128),
    K2        VARCHAR(128),
    V_SORT    VARCHAR(128),
    COLD1     VARCHAR(10000),
    COLD2     VARCHAR(10000),
    V_UPD     VARCHAR(10000)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_PR05
SELECT (G.GRP_ID - 1) * 12 + S.SEQ_NO AS ID,
       G.GRP_ID,
       'K1_' || LPAD(TO_CHAR(G.GRP_ID), 3, '0') || '_' || LPAD(TO_CHAR(S.SEQ_NO), 2, '0'),
       'K2_' || LPAD(TO_CHAR(MOD((G.GRP_ID * 7) + S.SEQ_NO, 193)), 3, '0'),
       LPAD(TO_CHAR(1000 - S.SEQ_NO), 4, '0'),
       RPAD('C1_' || TO_CHAR(G.GRP_ID) || '_' || TO_CHAR(S.SEQ_NO), 7000, 'X'),
       RPAD('C2_' || TO_CHAR(G.GRP_ID) || '_' || TO_CHAR(S.SEQ_NO), 7000, 'Y'),
       CASE
            WHEN S.SEQ_NO = 1 THEN RPAD('TOP_' || TO_CHAR(G.GRP_ID), 9100, 'T')
            WHEN MOD(S.SEQ_NO, 2) = 0 THEN RPAD('MID_' || TO_CHAR(G.GRP_ID) || '_' || TO_CHAR(S.SEQ_NO), 96, 'M')
            ELSE RPAD('LOW_' || TO_CHAR(G.GRP_ID) || '_' || TO_CHAR(S.SEQ_NO), 9050, 'L')
       END
  FROM (
        SELECT LEVEL AS GRP_ID
          FROM DUAL
        CONNECT BY LEVEL <= 40
       ) G,
       (
        SELECT LEVEL AS SEQ_NO
          FROM DUAL
        CONNECT BY LEVEL <= 12
       ) S;

SELECT GRP_ID,
       MIN(FV_LEN) AS MIN_FV_LEN,
       MAX(FV_LEN) AS MAX_FV_LEN,
       MIN(COLD_SIG) AS MIN_COLD_SIG,
       MAX(COLD_SIG) AS MAX_COLD_SIG,
       COUNT(*) AS CNT
  FROM (
        SELECT /*+ TEMP_TBS_DISK */
               GRP_ID,
               ROW_NUMBER() OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID) AS RN,
               DENSE_RANK() OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID) AS DRANK,
               LENGTH(FIRST_VALUE(V_UPD) OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID)) AS FV_LEN,
               (LENGTH(COLD1) + LENGTH(COLD2)) AS COLD_SIG
          FROM DST_COV_PR05
       ) W
 WHERE RN <= 2
 GROUP BY GRP_ID
 ORDER BY GRP_ID
 LIMIT 20;

SELECT ID,
       GRP_ID,
       LENGTH(FV) AS FV_LEN,
       RN,
       DRANK,
       LENGTH(COLD1) + LENGTH(COLD2) AS COLD_SIG
  FROM (
        SELECT /*+ TEMP_TBS_DISK */
               ID,
               GRP_ID,
               COLD1,
               COLD2,
               ROW_NUMBER() OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID) AS RN,
               DENSE_RANK() OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID) AS DRANK,
               FIRST_VALUE(V_UPD) OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID) AS FV
          FROM DST_COV_PR05
       ) W
 WHERE GRP_ID IN (1, 2, 3)
   AND RN <= 2
 ORDER BY GRP_ID, RN, ID;

SELECT CASE
           WHEN COUNT(*) = 40 THEN 1 ELSE 0
       END AS PASS_GROUP_SHAPE
  FROM (
        SELECT GRP_ID,
               MIN(FV_LEN) AS MIN_FV_LEN,
               MAX(FV_LEN) AS MAX_FV_LEN,
               MIN(COLD_SIG) AS MIN_COLD_SIG,
               MAX(COLD_SIG) AS MAX_COLD_SIG,
               COUNT(*) AS CNT
          FROM (
                SELECT /*+ TEMP_TBS_DISK */
                       GRP_ID,
                       ROW_NUMBER() OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID) AS RN,
                       LENGTH(FIRST_VALUE(V_UPD) OVER (PARTITION BY GRP_ID ORDER BY V_SORT DESC, ID)) AS FV_LEN,
                       (LENGTH(COLD1) + LENGTH(COLD2)) AS COLD_SIG
                  FROM DST_COV_PR05
               ) T
         WHERE RN <= 2
         GROUP BY GRP_ID
       ) G
 WHERE MIN_FV_LEN = 9100
   AND MAX_FV_LEN = 9100
   AND MIN_COLD_SIG = 14000
   AND MAX_COLD_SIG = 14000
   AND CNT = 2;

DROP TABLE DST_COV_PR05;
