-- Reference: doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md
--+TIMEOUT_SEC 600;
--+SYSTEM bash ./tests/tde/bin/tde_case.sh negative_invalid_keystore;
SELECT 1 FROM DUAL;
