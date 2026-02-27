-- Test Purpose: Verify INTERSECT result correctness and ordering stability.
-- Checks: Intersection membership and output ordering are correct.
-- Disk sort temp coverage SO03: INTERSECT + ORDER BY
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV_SO03_A;
DROP TABLE DST_COV_SO03_B;
--+SKIP_END;

CREATE TABLE DST_COV_SO03_A
(
    K1      INTEGER,
    K2      VARCHAR(64),
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV_SO03_B
(
    K1      INTEGER,
    K2      VARCHAR(64),
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_SO03_A
SELECT MOD(LEVEL, 400),
       'S' || TO_CHAR(MOD(LEVEL, 110)),
       RPAD('IA' || TO_CHAR(LEVEL), 3200, 'I')
  FROM DUAL
CONNECT BY LEVEL <= 1800;

INSERT INTO DST_COV_SO03_B
SELECT MOD(LEVEL + 120, 400),
       'S' || TO_CHAR(MOD(LEVEL, 110)),
       RPAD('IB' || TO_CHAR(LEVEL), 3200, 'J')
  FROM DUAL
CONNECT BY LEVEL <= 1800;

SELECT /*+ TEMP_TBS_DISK */ K1, K2
  FROM (
        SELECT K1, K2 FROM DST_COV_SO03_A
        INTERSECT
        SELECT K1, K2 FROM DST_COV_SO03_B
       ) X
 ORDER BY K1, K2
 LIMIT 100;

DROP TABLE DST_COV_SO03_A;
DROP TABLE DST_COV_SO03_B;
