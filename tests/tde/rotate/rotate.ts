./rotate_master_key.sql | timeout_sec=600
./rotate_restart_smoke.sql | timeout_sec=900
./rotate_twice_history.sql | timeout_sec=600
./rotate_new_encrypted_uses_new_key.sql | timeout_sec=600
./rotate_reference_count_check.sql | timeout_sec=600
./rotate_old_tbs_still_old_key.sql | timeout_sec=600
./negative_rotated_key_history.sql | timeout_sec=900
