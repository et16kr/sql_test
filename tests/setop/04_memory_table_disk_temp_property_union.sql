-- Test Purpose: Validate UNION DISTINCT on memory table with disk-temp default property.
-- Checks:
--   1) tables are created without TABLESPACE clause (memory table path)
--   2) __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2 is applied
--   3) union distinct result is correct
--   4) property is reset to default (0) at end
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DSET_COV04_A;
DROP TABLE DSET_COV04_B;
--+SKIP_END;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2;

SELECT CASE
           WHEN MEMORY_VALUE1 = '2' THEN 1 ELSE 0
       END AS PASS_PROP_SET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

CREATE TABLE DSET_COV04_A
(
    K1      INTEGER,
    K2      VARCHAR(64),
    PAD1    VARCHAR(512)
);

CREATE TABLE DSET_COV04_B
(
    K1      INTEGER,
    K2      VARCHAR(64),
    PAD1    VARCHAR(512)
);

INSERT INTO DSET_COV04_A
SELECT MOD(LEVEL, 300),
       'A' || TO_CHAR(MOD(LEVEL, 90)),
       RPAD('UA' || TO_CHAR(LEVEL), 300, 'A')
  FROM DUAL
CONNECT BY LEVEL <= 1200;

INSERT INTO DSET_COV04_B
SELECT MOD(LEVEL + 100, 300),
       'B' || TO_CHAR(MOD(LEVEL, 90)),
       RPAD('UB' || TO_CHAR(LEVEL), 300, 'B')
  FROM DUAL
CONNECT BY LEVEL <= 1200;

SELECT K1, K2
  FROM (
        SELECT K1, K2 FROM DSET_COV04_A
        UNION
        SELECT K1, K2 FROM DSET_COV04_B
       ) U
 ORDER BY K1, K2
 LIMIT 60;

SELECT CASE
           WHEN (
                SELECT COUNT(*)
                  FROM (
                        SELECT K1, K2 FROM DSET_COV04_A
                        UNION
                        SELECT K1, K2 FROM DSET_COV04_B
                       ) U
                ) = 600
           THEN 1 ELSE 0
       END AS PASS_UNION_DISTINCT_CNT
  FROM DUAL;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 0;

SELECT CASE
           WHEN MEMORY_VALUE1 = '0' THEN 1 ELSE 0
       END AS PASS_PROP_RESET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

DROP TABLE DSET_COV04_A;
DROP TABLE DSET_COV04_B;
