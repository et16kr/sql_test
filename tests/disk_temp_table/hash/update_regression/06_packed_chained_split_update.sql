-- Test Purpose: Validate packed chained GROUP_HASH update with split variable payload.
-- Checks:
--   1) MAX(V_UPD) keeps 9100-byte payload per group (split update write path).
--   2) Wide aggregate payloads remain stable (7000 + 7000).
--   3) Group cardinality and row-sum stay deterministic.
-- Disk hash temp packed-row coverage H16: chained packed update early-stop regression with split payload
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DHASH_COV16;
--+SKIP END;

CREATE TABLE DHASH_COV16
(
    ID      INTEGER,
    K1      VARCHAR(128),
    V_UPD   VARCHAR(10000),
    PAD1    VARCHAR(10000),
    PAD2    VARCHAR(10000),
    N1      INTEGER
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DHASH_COV16
SELECT (G.GRP_ID - 1) * 10 + S.SEQ_NO AS ID,
       'G' || LPAD(TO_CHAR(G.GRP_ID), 3, '0'),
       CASE
            WHEN S.SEQ_NO = 1 THEN RPAD('A_' || TO_CHAR(G.GRP_ID), 64, 'A')
            WHEN S.SEQ_NO = 2 THEN RPAD('M_' || TO_CHAR(G.GRP_ID), 9050, 'M')
            WHEN S.SEQ_NO = 3 THEN RPAD('Z_' || TO_CHAR(G.GRP_ID), 9100, 'Z')
            ELSE RPAD('B_' || TO_CHAR(G.GRP_ID) || '_' || TO_CHAR(S.SEQ_NO), 120, 'B')
       END,
       CASE
            WHEN S.SEQ_NO = 4 THEN RPAD('ZP_' || TO_CHAR(G.GRP_ID), 7000, 'P')
            ELSE RPAD('AP_' || TO_CHAR(G.GRP_ID) || '_' || TO_CHAR(S.SEQ_NO), 7000, 'A')
       END,
       CASE
            WHEN S.SEQ_NO = 5 THEN RPAD('ZQ_' || TO_CHAR(G.GRP_ID), 7000, 'Q')
            ELSE RPAD('AQ_' || TO_CHAR(G.GRP_ID) || '_' || TO_CHAR(S.SEQ_NO), 7000, 'A')
       END,
       MOD((G.GRP_ID * 37) + (S.SEQ_NO * 11), 1000)
  FROM (
        SELECT LEVEL AS GRP_ID
          FROM DUAL
        CONNECT BY LEVEL <= 64
       ) G,
       (
        SELECT LEVEL AS SEQ_NO
          FROM DUAL
        CONNECT BY LEVEL <= 10
       ) S;

SELECT /*+ TEMP_TBS_DISK GROUP_HASH */
       K1,
       COUNT(*) AS CNT_V,
       LENGTH(MAX(V_UPD)) AS LEN_MAX_V,
       LENGTH(MAX(PAD1)) AS LEN_MAX_P1,
       LENGTH(MAX(PAD2)) AS LEN_MAX_P2,
       SUM(N1) AS SUM_N1
  FROM DHASH_COV16
 GROUP BY K1
 ORDER BY K1
 LIMIT 20;

SELECT CASE
           WHEN COUNT(*) = 64 THEN 1 ELSE 0
       END AS PASS_GROUP_SHAPE
  FROM (
        SELECT /*+ TEMP_TBS_DISK GROUP_HASH */
               K1,
               LENGTH(MAX(V_UPD)) AS LEN_MAX_V,
               LENGTH(MAX(PAD1)) AS LEN_MAX_P1,
               LENGTH(MAX(PAD2)) AS LEN_MAX_P2,
               COUNT(*) AS CNT_V
          FROM DHASH_COV16
         GROUP BY K1
       ) G
 WHERE LEN_MAX_V = 9100
   AND LEN_MAX_P1 = 7000
   AND LEN_MAX_P2 = 7000
   AND CNT_V = 10;

SELECT CASE
           WHEN SUM(CNT_V) = 640 THEN 1 ELSE 0
       END AS PASS_ROW_SUM
  FROM (
        SELECT /*+ TEMP_TBS_DISK GROUP_HASH */
               K1,
               COUNT(*) AS CNT_V
          FROM DHASH_COV16
         GROUP BY K1
       ) G;

DROP TABLE DHASH_COV16;
