-- Test Purpose: Verify packed-row hash path for insert plus GROUP_HASH scan.
-- Checks: Grouped counts and max-length aggregates match inserted packed rows.
-- Disk hash temp packed-row coverage H01: packed insert + group scan
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DHASH_COV01;
--+SKIP_END;

CREATE TABLE DHASH_COV01
(
    ID       INTEGER,
    K1       VARCHAR(256),
    V1       VARCHAR(4000),
    V2       VARCHAR(4000)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DHASH_COV01
SELECT LEVEL,
       'K' || LPAD(TO_CHAR(MOD(LEVEL, 173)), 4, '0'),
       CASE WHEN MOD(LEVEL, 11) = 0 THEN NULL
            WHEN MOD(LEVEL, 11) = 1 THEN 'S'
            ELSE RPAD('V1_' || TO_CHAR(LEVEL), MOD(LEVEL * 13, 3900) + 50, 'A') END,
       RPAD('V2_' || TO_CHAR(MOD(LEVEL, 300)), MOD(LEVEL * 17, 3900) + 60, 'B')
  FROM DUAL
CONNECT BY LEVEL <= 2600;

SELECT /*+ TEMP_TBS_DISK GROUP_HASH */
       K1,
       COUNT(*) AS CNT,
       MAX(NVL(LENGTH(V1), 0)) AS MAX_L1,
       MAX(NVL(LENGTH(V2), 0)) AS MAX_L2
  FROM DHASH_COV01
 GROUP BY K1
 ORDER BY K1
 LIMIT 40;

SELECT CASE WHEN SUM(CNT) = 2600 THEN 1 ELSE 0 END AS PASS_SUM
  FROM (
        SELECT /*+ TEMP_TBS_DISK GROUP_HASH */
               COUNT(*) AS CNT
          FROM DHASH_COV01
         GROUP BY K1
       ) X;

DROP TABLE DHASH_COV01;
