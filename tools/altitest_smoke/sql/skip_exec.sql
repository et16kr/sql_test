-- header before SKIP should not force a separate visible iSQL run
--+SKIP BEGIN;
--CASE:STATE SET skip_block_ran
--+SKIP END;
--CASE:STATE REQUIRE skip_block_ran
SELECT 1;
