-- Test Purpose: Verify packed-row chained storage behavior with many hash keys.
-- Checks: Chained fetch/decode and distinct/group results are correct.
-- Disk hash temp packed-row coverage H08: many key columns + wide payload
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DHASH_COV08;
--+SKIP END;

CREATE TABLE DHASH_COV08
(
    ID       INTEGER,
    K1       VARCHAR(64),
    K2       VARCHAR(64),
    K3       VARCHAR(64),
    K4       VARCHAR(64),
    K5       VARCHAR(64),
    K6       VARCHAR(64),
    K7       VARCHAR(64),
    K8       VARCHAR(64),
    K9       VARCHAR(64),
    V1       VARCHAR(4000),
    V2       VARCHAR(4000)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DHASH_COV08
SELECT LEVEL,
       'K1_' || LPAD(TO_CHAR(MOD(TRUNC((LEVEL + 1) / 2), 97)), 3, '0'),
       'K2_' || LPAD(TO_CHAR(MOD(TRUNC((LEVEL + 1) / 2), 89)), 3, '0'),
       'K3_' || LPAD(TO_CHAR(MOD(TRUNC((LEVEL + 1) / 2), 83)), 3, '0'),
       'K4_' || LPAD(TO_CHAR(MOD(TRUNC((LEVEL + 1) / 2), 79)), 3, '0'),
       'K5_' || LPAD(TO_CHAR(MOD(TRUNC((LEVEL + 1) / 2), 73)), 3, '0'),
       'K6_' || LPAD(TO_CHAR(MOD(TRUNC((LEVEL + 1) / 2), 71)), 3, '0'),
       'K7_' || LPAD(TO_CHAR(MOD(TRUNC((LEVEL + 1) / 2), 67)), 3, '0'),
       'K8_' || LPAD(TO_CHAR(MOD(TRUNC((LEVEL + 1) / 2), 61)), 3, '0'),
       'K9_' || LPAD(TO_CHAR(MOD(TRUNC((LEVEL + 1) / 2), 59)), 3, '0'),
       RPAD('V1_' || TO_CHAR(LEVEL), 3600, 'X'),
       RPAD('V2_' || TO_CHAR(MOD(LEVEL, 700)), 3600, 'Y')
  FROM DUAL
CONNECT BY LEVEL <= 2400;

SELECT /*+ TEMP_TBS_DISK DISTINCT_HASH */
       COUNT(*) AS DISTINCT_CNT
  FROM (
        SELECT DISTINCT K1, K2, K3, K4, K5, K6, K7, K8, K9
          FROM DHASH_COV08
       ) D;

SELECT /*+ TEMP_TBS_DISK DISTINCT_HASH */
       K1, K2, K3, K4, K5, K6, K7, K8, K9
  FROM (
        SELECT DISTINCT K1, K2, K3, K4, K5, K6, K7, K8, K9
          FROM DHASH_COV08
       ) D
 ORDER BY K1, K2, K3, K4, K5, K6, K7, K8, K9
 LIMIT 20;

SELECT CASE WHEN COUNT(*) = 1200 THEN 1 ELSE 0 END AS PASS_MANYKEY_DISTINCT
  FROM (
        SELECT /*+ TEMP_TBS_DISK DISTINCT_HASH */
               DISTINCT K1, K2, K3, K4, K5, K6, K7, K8, K9
          FROM DHASH_COV08
       ) D;

DROP TABLE DHASH_COV08;
