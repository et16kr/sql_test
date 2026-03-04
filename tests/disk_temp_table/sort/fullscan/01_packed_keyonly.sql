-- Test Purpose: Verify packed-row full scan with ORDER BY can decode key/value columns correctly.
-- Checks: Ordered result slice is stable and total row count matches inserted rows.
-- Disk sort temp coverage 01: full scan + packed row + key-only compare path
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV01;
--+SKIP END;

CREATE TABLE DST_COV01
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    K1       VARCHAR(64),
    K2       VARCHAR(64),
    V1       VARCHAR(3200),
    V2       VARCHAR(3200),
    V3       VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV01
SELECT LEVEL,
       MOD(LEVEL, 37),
       LPAD(TO_CHAR(MOD(LEVEL, 1000)), 8, '0'),
       LPAD(TO_CHAR(MOD(LEVEL, 500)), 8, '0'),
       RPAD('A' || TO_CHAR(LEVEL), 3200, 'A'),
       RPAD('B' || TO_CHAR(MOD(LEVEL, 200)), 3200, 'B'),
       RPAD('C' || TO_CHAR(MOD(LEVEL, 100)), 3200, 'C')
  FROM DUAL
CONNECT BY LEVEL <= 2000;

SELECT /*+ TEMP_TBS_DISK */ ID, GRP_ID
  FROM DST_COV01
 ORDER BY K1, K2, ID
 LIMIT 50;

SELECT CASE WHEN COUNT(*) = 2000 THEN 1 ELSE 0 END AS PASS_COUNT
  FROM DST_COV01;

DROP TABLE DST_COV01;
