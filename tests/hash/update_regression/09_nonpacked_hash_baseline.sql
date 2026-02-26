-- Test Purpose: Provide non-packed hash baseline to detect regression from packed-row changes.
-- Checks: Existing hash group/join behaviors remain unchanged.
-- Disk hash temp coverage H09: non-packed regression baseline (fixed columns only)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DHASH_COV09;
DROP TABLE DHASH_COV09_B;
--+SKIP END;

CREATE TABLE DHASH_COV09
(
    ID       INTEGER,
    C1       CHAR(8),
    C2       CHAR(8),
    N1       NUMERIC(12)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DHASH_COV09_B
(
    ID       INTEGER,
    C1       CHAR(8),
    N2       NUMERIC(12)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DHASH_COV09
SELECT LEVEL,
       LPAD(TO_CHAR(MOD(LEVEL, 300)), 8, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 200)), 8, '0'),
       MOD(LEVEL * 19, 100000)
  FROM DUAL
CONNECT BY LEVEL <= 2200;

INSERT INTO DHASH_COV09_B
SELECT LEVEL,
       LPAD(TO_CHAR(MOD(LEVEL, 300)), 8, '0'),
       MOD(LEVEL * 23, 100000)
  FROM DUAL
CONNECT BY LEVEL <= 1500;

SELECT /*+ TEMP_TBS_DISK GROUP_HASH */
       C1,
       C2,
       COUNT(*) AS CNT_V,
       SUM(N1) AS SUM_V
  FROM DHASH_COV09
 GROUP BY C1, C2
 ORDER BY C1, C2
 LIMIT 30;

SELECT CASE WHEN SUM(CNT_V) = 2200 THEN 1 ELSE 0 END AS PASS_GROUP_CNT
  FROM (
        SELECT /*+ TEMP_TBS_DISK GROUP_HASH */
               C1,
               C2,
               COUNT(*) AS CNT_V
          FROM DHASH_COV09
         GROUP BY C1, C2
       ) G;

SELECT /*+ TEMP_TBS_DISK ORDERED USE_HASH(B, A) */
       COUNT(*) AS JOIN_CNT
  FROM DHASH_COV09 A, DHASH_COV09_B B
 WHERE A.C1 = B.C1;

DROP TABLE DHASH_COV09;
DROP TABLE DHASH_COV09_B;
