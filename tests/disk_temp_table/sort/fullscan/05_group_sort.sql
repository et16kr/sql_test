-- Test Purpose: Verify GROUP_SORT aggregation correctness on disk temp path.
-- Checks: Group cardinality and aggregate results are correct.
-- Disk sort temp coverage 05: GROUP_SORT with packed-row candidate columns
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP BEGIN;
DROP TABLE DST_COV05;
--+SKIP END;

CREATE TABLE DST_COV05
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    PAD_KEY  VARCHAR(128),
    PAD_VAL  VARCHAR(3200),
    N1       NUMERIC(12)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV05
SELECT LEVEL,
       MOD(LEVEL, 64),
       RPAD('G' || TO_CHAR(MOD(LEVEL, 64)), 128, 'G'),
       RPAD('V' || TO_CHAR(MOD(LEVEL, 256)), 3200, 'V'),
       MOD(LEVEL * 19, 100000)
  FROM DUAL
CONNECT BY LEVEL <= 2500;

SELECT /*+ TEMP_TBS_DISK GROUP_SORT */
       GRP_ID,
       COUNT(*) AS CNT,
       MAX(PAD_KEY) AS MAX_KEY
  FROM DST_COV05
 GROUP BY GRP_ID
 ORDER BY GRP_ID;

DROP TABLE DST_COV05;
