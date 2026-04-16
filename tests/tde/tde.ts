./00_bootstrap_create/test.sql | timeout_sec=600
./01_view_check/test.sql | timeout_sec=600
./10_restart_smoke/test.sql | timeout_sec=600
./20_negative_wrap_key/test.sql | timeout_sec=600
./30_negative_invalid_keystore/test.sql | timeout_sec=600
./40_negative_missing_master_key/test.sql | timeout_sec=600
./50_negative_autoload_off/test.sql | timeout_sec=600
./90_cleanup/test.sql | timeout_sec=600
