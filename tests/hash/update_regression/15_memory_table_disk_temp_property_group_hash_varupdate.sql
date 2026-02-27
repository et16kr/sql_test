-- Test Purpose: Validate GROUP_HASH aggregate-update path on memory table with disk-temp default property.
-- Checks:
--   1) table is created without TABLESPACE clause (memory table path)
--   2) __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2 is applied
--   3) GROUP_HASH with MIN/MAX(varchar) returns deterministic grouped result
--   4) property is reset to default (0) at end
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DHASH_COV15_MEM_VARUPD;
--+SKIP_END;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2;

SELECT CASE
           WHEN MEMORY_VALUE1 = '2' THEN 1 ELSE 0
       END AS PASS_PROP_SET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

CREATE TABLE DHASH_COV15_MEM_VARUPD
(
    ID      INTEGER,
    K1      VARCHAR(128),
    V1      VARCHAR(3200),
    N1      INTEGER
);

INSERT INTO DHASH_COV15_MEM_VARUPD
SELECT LEVEL,
       'G' || LPAD(TO_CHAR(MOD(LEVEL, 173)), 4, '0'),
       CASE MOD(LEVEL, 3)
            WHEN 0 THEN RPAD('A' || TO_CHAR(LEVEL), 17, 'A')
            WHEN 1 THEN RPAD('B' || TO_CHAR(LEVEL), 33, 'B')
            ELSE RPAD('C' || TO_CHAR(LEVEL), 3000, 'C')
       END,
       MOD(LEVEL * 13, 1000)
  FROM DUAL
CONNECT BY LEVEL <= 9000;

SELECT K1,
       CNT_V,
       LEN_MIN_V1,
       LEN_MAX_V1,
       SUM_N1
  FROM (
        SELECT /*+ GROUP_HASH */
               K1,
               COUNT(*) AS CNT_V,
               LENGTH(MIN(V1)) AS LEN_MIN_V1,
               LENGTH(MAX(V1)) AS LEN_MAX_V1,
               SUM(N1) AS SUM_N1
          FROM DHASH_COV15_MEM_VARUPD
         GROUP BY K1
       ) G
 ORDER BY K1
 LIMIT 35;

SELECT CASE
           WHEN (
                SELECT COUNT(*)
                  FROM (
                        SELECT /*+ GROUP_HASH */
                               K1
                          FROM DHASH_COV15_MEM_VARUPD
                         GROUP BY K1
                       ) G
                ) = 173
           THEN 1 ELSE 0
       END AS PASS_GROUP_CNT
  FROM DUAL;

SELECT CASE
           WHEN (
                SELECT SUM(CNT_V)
                  FROM (
                        SELECT /*+ GROUP_HASH */
                               K1,
                               COUNT(*) AS CNT_V
                          FROM DHASH_COV15_MEM_VARUPD
                         GROUP BY K1
                       ) G
                ) = 9000
           THEN 1 ELSE 0
       END AS PASS_ROW_SUM
  FROM DUAL;

SELECT CASE
           WHEN (
                SELECT COUNT(*)
                  FROM (
                        SELECT /*+ GROUP_HASH */
                               K1,
                               LENGTH(MIN(V1)) AS LEN_MIN_V1,
                               LENGTH(MAX(V1)) AS LEN_MAX_V1
                          FROM DHASH_COV15_MEM_VARUPD
                         GROUP BY K1
                       ) G
                 WHERE LEN_MIN_V1 = 17
                   AND LEN_MAX_V1 = 3000
                ) = 173
           THEN 1 ELSE 0
       END AS PASS_LEN_BOUNDARY
  FROM DUAL;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 0;

SELECT CASE
           WHEN MEMORY_VALUE1 = '0' THEN 1 ELSE 0
       END AS PASS_PROP_RESET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

DROP TABLE DHASH_COV15_MEM_VARUPD;
