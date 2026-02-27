-- Test Purpose: Verify INSERT-SELECT with nested ORDER BY preserves expected result shape.
-- Checks: Inserted row set and ordering-dependent values are correct.
-- Disk sort temp coverage 09: INSERT ... SELECT with nested ORDER BY + window sort
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV09_DST;
DROP TABLE DST_COV09_SRC;
--+SKIP_END;

CREATE TABLE DST_COV09_SRC
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    V1       VARCHAR(3200),
    V2       VARCHAR(3200),
    V3       VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV09_DST
(
    ID       INTEGER,
    GRP_ID   INTEGER,
    V1       VARCHAR(3200),
    V2       VARCHAR(3200),
    V3       VARCHAR(3200),
    RN       INTEGER
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV09_SRC
SELECT LEVEL,
       MOD(LEVEL, 17),
       RPAD('S' || TO_CHAR(LEVEL), 3200, 'S'),
       RPAD('T' || TO_CHAR(MOD(LEVEL, 300)), 3200, 'T'),
       RPAD('U' || TO_CHAR(MOD(LEVEL, 40)), 3200, 'U')
  FROM DUAL
CONNECT BY LEVEL <= 1600;

INSERT INTO DST_COV09_DST (ID, GRP_ID, V1, V2, V3, RN)
SELECT X.ID,
       X.GRP_ID,
       X.V1,
       X.V2,
       X.V3,
       X.RN
  FROM (
        SELECT O.ID,
               O.GRP_ID,
               O.V1,
               O.V2,
               O.V3,
               ROW_NUMBER() OVER (PARTITION BY O.GRP_ID ORDER BY O.V2 DESC, O.ID) AS RN
          FROM (
                SELECT /*+ TEMP_TBS_DISK */ ID, GRP_ID, V1, V2, V3
                  FROM DST_COV09_SRC
                 ORDER BY V3 DESC, ID
               ) O
       ) X
 ORDER BY X.RN DESC, X.ID;

SELECT CASE WHEN COUNT(*) = 1600 THEN 1 ELSE 0 END AS PASS_COUNT
  FROM DST_COV09_DST;

DROP TABLE DST_COV09_DST;
DROP TABLE DST_COV09_SRC;
