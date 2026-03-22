-- Test Purpose: Regress the external altidev4 create/test/drop workflow as a single sql_test case.
-- Checks: The large real-world query in altidev4/tests/test.sql completes under sql_test and returns 8 rows.
-- Disk sort temp coverage BUG02: external financial-report scalar-subquery regression
-- Source SQL:
--   /home/et16/work/altidev4/tests/create.sql
--   /home/et16/work/altidev4/tests/test.sql
--   /home/et16/work/altidev4/tests/drop.sql

--+SET_ENV ISQL_BUFFER_SIZE=256000;
--+TIMEOUT_SEC 600;

--+SKIP BEGIN;
START /home/et16/work/altidev4/tests/create.sql
--+SKIP END;

START /home/et16/work/altidev4/tests/test.sql
START /home/et16/work/altidev4/tests/drop.sql
