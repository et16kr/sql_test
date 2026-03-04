-- Test Purpose: Verify MINUS set operation correctness on sort temp path.
-- Checks: Set subtraction result matches expected rows.
-- Disk sort temp coverage 17: MINUS + ORDER BY (set operation with disk temp)
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV17_A;
DROP TABLE DST_COV17_B;
--+SKIP END;

CREATE TABLE DST_COV17_A
(
    K1     INTEGER,
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV17_B
(
    K1     INTEGER,
    PAD1   VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV17_A
SELECT LEVEL,
       RPAD('MA' || TO_CHAR(LEVEL), 3200, 'M')
  FROM DUAL
CONNECT BY LEVEL <= 1500;

INSERT INTO DST_COV17_B
SELECT LEVEL * 2,
       RPAD('MB' || TO_CHAR(LEVEL), 3200, 'N')
  FROM DUAL
CONNECT BY LEVEL <= 900;

SELECT /*+ TEMP_TBS_DISK */ K1
  FROM (
        SELECT K1 FROM DST_COV17_A
        MINUS
        SELECT K1 FROM DST_COV17_B
       ) M
 ORDER BY K1
 LIMIT 80;

DROP TABLE DST_COV17_A;
DROP TABLE DST_COV17_B;
