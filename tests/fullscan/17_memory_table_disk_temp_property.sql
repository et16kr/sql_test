-- Test Purpose: Validate disk temp execution on memory table by property.
-- Checks:
--   1) table is created without TABLESPACE clause (memory table path)
--   2) __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2 is applied
--   3) query result is correct
--   4) property is reset to default (0) at end
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV_FS17_MEM;
--+SKIP END;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 2;

SELECT CASE
           WHEN MEMORY_VALUE1 = '2' THEN 1 ELSE 0
       END AS PASS_PROP_SET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

CREATE TABLE DST_COV_FS17_MEM
(
    ID      INTEGER,
    K1      VARCHAR(128),
    PAD1    VARCHAR(512)
);

INSERT INTO DST_COV_FS17_MEM
SELECT LEVEL,
       'K' || LPAD(TO_CHAR(MOD(LEVEL, 701)), 4, '0'),
       RPAD('M' || TO_CHAR(MOD(LEVEL, 701)), 300, 'M')
  FROM DUAL
CONNECT BY LEVEL <= 4000;

SELECT ID,
       K1
  FROM DST_COV_FS17_MEM
 ORDER BY K1, ID
 LIMIT 20;

SELECT CASE WHEN COUNT(*) = 4000 THEN 1 ELSE 0 END AS PASS_COUNT
  FROM DST_COV_FS17_MEM;

ALTER SYSTEM SET __OPTIMIZER_DEFAULT_TEMP_TBS_TYPE = 0;

SELECT CASE
           WHEN MEMORY_VALUE1 = '0' THEN 1 ELSE 0
       END AS PASS_PROP_RESET
  FROM X$PROPERTY
 WHERE NAME = '__OPTIMIZER_DEFAULT_TEMP_TBS_TYPE';

DROP TABLE DST_COV_FS17_MEM;
