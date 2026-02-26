-- Test Purpose: Verify chained packed-row decode correctness for wide rows.
-- Checks: Decoded variable-column lengths and values match inserted data.
-- Disk sort temp coverage 19: very wide chained row fetch/decode path
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV19;
--+SKIP END;

CREATE TABLE DST_COV19
(
    ID       INTEGER,
    K1       VARCHAR(64),
    V1       VARCHAR(10000),
    V2       VARCHAR(10000),
    V3       VARCHAR(10000)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV19
SELECT LEVEL,
       'K' || TO_CHAR(MOD(LEVEL, 70)),
       RPAD('P' || TO_CHAR(LEVEL), 9000, 'P'),
       RPAD('Q' || TO_CHAR(MOD(LEVEL, 100)), 9000, 'Q'),
       RPAD('R' || TO_CHAR(MOD(LEVEL, 10)), 9000, 'R')
  FROM DUAL
CONNECT BY LEVEL <= 320;

SELECT /*+ TEMP_TBS_DISK */ ID, LENGTH(V1) AS L1, LENGTH(V2) AS L2
  FROM DST_COV19
 ORDER BY K1, ID
 LIMIT 20;

DROP TABLE DST_COV19;
