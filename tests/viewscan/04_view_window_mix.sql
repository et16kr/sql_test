-- Test Purpose: Verify combined view scan and window-function path correctness.
-- Checks: View expansion and window output are both correct.
-- Disk sort temp coverage VS04: NO_MERGE view + windowing mix
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV_VS04_BASE;
--+SKIP_END;

CREATE TABLE DST_COV_VS04_BASE
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    PAD1     VARCHAR(3200),
    PAD2     VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_VS04_BASE
SELECT LEVEL,
       MOD(LEVEL, 37),
       RPAD('X' || TO_CHAR(LEVEL), 3200, 'X'),
       RPAD('Y' || TO_CHAR(MOD(LEVEL, 120)), 3200, 'Y')
  FROM DUAL
CONNECT BY LEVEL <= 1700;

SELECT ID, GRP_ID, RN
  FROM (
        SELECT /*+ TEMP_TBS_DISK NO_MERGE(V) */
               V.ID,
               V.GRP_ID,
               ROW_NUMBER() OVER (PARTITION BY V.GRP_ID ORDER BY V.ID DESC) AS RN
          FROM (
                SELECT ID, GRP_ID, PAD1
                  FROM DST_COV_VS04_BASE
                 ORDER BY GRP_ID, ID DESC
               ) V
       ) X
 WHERE RN <= 2
 ORDER BY GRP_ID, RN, ID;

DROP TABLE DST_COV_VS04_BASE;
