-- Test Purpose: Verify UNION DISTINCT set operation correctness on sort temp path.
-- Checks: Duplicate elimination and final ordering are correct.
-- Disk sort temp coverage 16: UNION (distinct) + ORDER BY on disk temp
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV16_A;
DROP TABLE DST_COV16_B;
--+SKIP_END;

CREATE TABLE DST_COV16_A
(
    K1     INTEGER,
    K2     VARCHAR(64),
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV16_B
(
    K1     INTEGER,
    K2     VARCHAR(64),
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV16_A
SELECT MOD(LEVEL, 300),
       'A' || TO_CHAR(MOD(LEVEL, 90)),
       RPAD('UA' || TO_CHAR(LEVEL), 3200, 'A')
  FROM DUAL
CONNECT BY LEVEL <= 1200;

INSERT INTO DST_COV16_B
SELECT MOD(LEVEL + 100, 300),
       'B' || TO_CHAR(MOD(LEVEL, 90)),
       RPAD('UB' || TO_CHAR(LEVEL), 3200, 'B')
  FROM DUAL
CONNECT BY LEVEL <= 1200;

SELECT /*+ TEMP_TBS_DISK */ K1, K2
  FROM (
        SELECT K1, K2 FROM DST_COV16_A
        UNION
        SELECT K1, K2 FROM DST_COV16_B
       ) U
 ORDER BY K1, K2
 LIMIT 80;

DROP TABLE DST_COV16_A;
DROP TABLE DST_COV16_B;
