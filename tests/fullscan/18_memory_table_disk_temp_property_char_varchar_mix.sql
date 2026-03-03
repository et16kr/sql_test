-- Test Purpose: Validate disk sort/group behavior on memory table with CHAR(>16) + VARCHAR mix.
-- Checks:
--   1) table is created without TABLESPACE clause (memory table path)
--   2) __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2 is applied
--   3) GROUP BY and ORDER BY with mixed fixed/variable columns return deterministic results
--   4) property is reset to default (0) at end
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV_FS18_MEM_MIX;
--+SKIP END;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2;

SELECT CASE
           WHEN MEMORY_VALUE1 = '2' THEN 1 ELSE 0
       END AS PASS_PROP_SET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

CREATE TABLE DST_COV_FS18_MEM_MIX
(
    ID       INTEGER,
    C1       CHAR(32),
    V1       VARCHAR(3200),
    V2       VARCHAR(256)
);

INSERT INTO DST_COV_FS18_MEM_MIX
SELECT LEVEL,
       RPAD(CHR(65 + MOD(LEVEL, 26)), 32, CHR(65 + MOD(LEVEL, 26))),
       CASE MOD(LEVEL, 3)
            WHEN 0 THEN RPAD('A' || TO_CHAR(LEVEL), 17, 'A')
            WHEN 1 THEN RPAD('B' || TO_CHAR(LEVEL), 33, 'B')
            ELSE RPAD('C' || TO_CHAR(LEVEL), 3000, 'C')
       END,
       RPAD('S' || TO_CHAR(MOD(LEVEL, 151)), 200, 'S')
  FROM DUAL
CONNECT BY LEVEL <= 6000;

SELECT C1,
       CNT_V,
       MIN_L1,
       MAX_L1
  FROM (
        SELECT C1,
               COUNT(*) AS CNT_V,
               MIN(LENGTH(V1)) AS MIN_L1,
               MAX(LENGTH(V1)) AS MAX_L1
          FROM DST_COV_FS18_MEM_MIX
         GROUP BY C1
       ) G
 ORDER BY C1
 LIMIT 12;

SELECT ID,
       C1
  FROM DST_COV_FS18_MEM_MIX
 ORDER BY C1, V2 DESC, ID
 LIMIT 40;

SELECT CASE
           WHEN (
                SELECT COUNT(*)
                  FROM (
                        SELECT C1
                          FROM DST_COV_FS18_MEM_MIX
                         GROUP BY C1
                       ) G
                ) = 26
           THEN 1 ELSE 0
       END AS PASS_GROUP_CNT
  FROM DUAL;

SELECT CASE
           WHEN (
                SELECT SUM(CNT_V)
                  FROM (
                        SELECT C1, COUNT(*) AS CNT_V
                          FROM DST_COV_FS18_MEM_MIX
                         GROUP BY C1
                       ) G
                ) = 6000
           THEN 1 ELSE 0
       END AS PASS_ROW_SUM
  FROM DUAL;

SELECT CASE
           WHEN (
                SELECT COUNT(*)
                  FROM (
                        SELECT C1,
                               MIN(LENGTH(V1)) AS MIN_L1,
                               MAX(LENGTH(V1)) AS MAX_L1
                          FROM DST_COV_FS18_MEM_MIX
                         GROUP BY C1
                       ) G
                 WHERE MIN_L1 = 17
                   AND MAX_L1 = 3000
                ) = 26
           THEN 1 ELSE 0
       END AS PASS_LEN_BOUNDARY
  FROM DUAL;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 0;

SELECT CASE
           WHEN MEMORY_VALUE1 = '0' THEN 1 ELSE 0
       END AS PASS_PROP_RESET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

DROP TABLE DST_COV_FS18_MEM_MIX;
