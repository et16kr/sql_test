-- Test Purpose: Verify DISTINCT_HASH duplicate handling when variable-length keys share same length.
-- Checks: Duplicate keys with same physical length are deduplicated correctly.
-- Disk hash temp packed-row coverage H02: distinct(unique) with same-length duplicates
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DHASH_COV02;
--+SKIP END;

CREATE TABLE DHASH_COV02
(
    ID       INTEGER,
    K1       VARCHAR(120),
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DHASH_COV02
SELECT LEVEL,
       'KEY_' || LPAD(TO_CHAR(MOD(LEVEL, 200)), 3, '0'),
       RPAD('P' || TO_CHAR(LEVEL), 3200, 'P')
  FROM DUAL
CONNECT BY LEVEL <= 3000;

SELECT /*+ TEMP_TBS_DISK DISTINCT_HASH */
       COUNT(*) AS DISTINCT_CNT
  FROM (
        SELECT DISTINCT K1
          FROM DHASH_COV02
       ) D;

SELECT /*+ TEMP_TBS_DISK DISTINCT_HASH */
       K1
  FROM (
        SELECT DISTINCT K1
          FROM DHASH_COV02
       ) D
 ORDER BY K1
 LIMIT 30;

SELECT CASE WHEN COUNT(*) = 200 THEN 1 ELSE 0 END AS PASS_DISTINCT_CNT
  FROM (
        SELECT /*+ TEMP_TBS_DISK DISTINCT_HASH */ DISTINCT K1
          FROM DHASH_COV02
       ) D;

DROP TABLE DHASH_COV02;
