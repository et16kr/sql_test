-- Test Purpose: Verify LEFT OUTER join with additional conditions keeps outer semantics.
-- Checks: Predicate handling does not incorrectly drop required outer rows.
-- Disk sort temp coverage HN05: LEFT OUTER with additional join predicate
-- Manual reference:
--   docs/manuals/altibase/Altibase_7.1/eng/iSQL User's Manual.md
--   docs/manuals/altibase/Altibase_7.1/eng/Performance Tuning Guide.md

--+SKIP_BEGIN;
DROP TABLE DST_COV_HN05_A;
DROP TABLE DST_COV_HN05_B;
--+SKIP_END;

CREATE TABLE DST_COV_HN05_A
(
    ID      INTEGER,
    K1      INTEGER,
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

CREATE TABLE DST_COV_HN05_B
(
    ID      INTEGER,
    K1      INTEGER,
    TAG     CHAR(1),
    PAD1    VARCHAR(3200)
) TABLESPACE SYS_TBS_DISK_DATA;

INSERT INTO DST_COV_HN05_A
SELECT LEVEL,
       MOD(LEVEL, 900),
       RPAD('LA' || TO_CHAR(LEVEL), 3200, 'L')
  FROM DUAL
CONNECT BY LEVEL <= 1300;

INSERT INTO DST_COV_HN05_B
SELECT LEVEL,
       MOD(LEVEL, 900),
       CASE WHEN MOD(LEVEL, 3) = 0 THEN 'Y' ELSE 'N' END,
       RPAD('LB' || TO_CHAR(LEVEL), 3200, 'M')
  FROM DUAL
CONNECT BY LEVEL <= 900;

SELECT /*+ TEMP_TBS_DISK USE_SORT(B, A) NO_USE_HASH(B) */
       SUM(CASE WHEN B.K1 IS NULL THEN 1 ELSE 0 END) AS LEFT_ONLY_CNT,
       COUNT(*) AS TOTAL_CNT
  FROM DST_COV_HN05_A A LEFT OUTER JOIN DST_COV_HN05_B B
    ON A.K1 = B.K1
   AND B.TAG = 'Y';

DROP TABLE DST_COV_HN05_A;
DROP TABLE DST_COV_HN05_B;
