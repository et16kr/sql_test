-- Test Purpose: Verify DISTINCT_HASH distinguishes keys with same prefix but different real lengths.
-- Checks: Length-sensitive uniqueness works for packed variable columns.
-- Disk hash temp packed-row coverage H03: same prefix, different actual var length
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DHASH_COV03;
--+SKIP END;

CREATE TABLE DHASH_COV03
(
    ID       INTEGER,
    K1       VARCHAR(128),
    PAD1     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DHASH_COV03
SELECT LEVEL,
       CASE MOD(LEVEL, 5)
            WHEN 0 THEN 'PX'
            WHEN 1 THEN 'PXA'
            WHEN 2 THEN 'PXAA'
            WHEN 3 THEN 'PXAAA'
            ELSE 'PXAAAA'
       END,
       RPAD('Q' || TO_CHAR(LEVEL), 3200, 'Q')
  FROM DUAL
CONNECT BY LEVEL <= 2500;

SELECT /*+ TEMP_TBS_DISK DISTINCT_HASH */
       K1,
       LENGTH(K1) AS L1
  FROM (
        SELECT DISTINCT K1
          FROM DHASH_COV03
       ) D
 ORDER BY L1, K1;

SELECT CASE WHEN COUNT(*) = 5 THEN 1 ELSE 0 END AS PASS_PREFIX_LEN
  FROM (
        SELECT /*+ TEMP_TBS_DISK DISTINCT_HASH */ DISTINCT K1
          FROM DHASH_COV03
       ) D;

DROP TABLE DHASH_COV03;
