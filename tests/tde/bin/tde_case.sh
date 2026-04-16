#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "${SCRIPT_DIR}/tde_common.sh"
. "${SCRIPT_DIR}/tde_lifecycle.sh"
. "${SCRIPT_DIR}/tde_fixture.sh"
. "${SCRIPT_DIR}/tde_startup_negative.sh"
. "${SCRIPT_DIR}/tde_rotate.sh"
. "${SCRIPT_DIR}/tde_convert.sh"
. "${SCRIPT_DIR}/tde_snapshot.sh"
. "${SCRIPT_DIR}/tde_repro.sh"

case "${1:-}" in
    case_guard)
        tde_case_guard
        ;;
    reset_environment)
        tde_reset_environment
        ;;
    prepare_base_fixture)
        tde_prepare_base_fixture
        ;;
    finalize_environment)
        tde_finalize_environment
        ;;
    restart_smoke)
        tde_restart_smoke
        ;;
    restart_repeat_smoke)
        tde_restart_repeat_smoke
        ;;
    restart_after_checkpoint)
        tde_restart_after_checkpoint
        ;;
    rotate_master_key)
        tde_rotate_master_key_once
        ;;
    prepare_temp_plain_fixture)
        tde_prepare_temp_plain_fixture
        ;;
    prepare_extended_fixture)
        tde_prepare_extended_fixture
        ;;
    prepare_rotate_once_fixture)
        tde_prepare_rotate_once_fixture
        ;;
    prepare_rotate_twice_fixture)
        tde_prepare_rotate_twice_fixture
        ;;
    prepare_rekey_fixture)
        tde_prepare_rekey_fixture
        ;;
    prepare_new_encrypted_fixture)
        tde_prepare_new_encrypted_fixture
        ;;
    prepare_empty_plain_fixture)
        tde_prepare_empty_plain_fixture
        ;;
    prepare_empty_encrypted_fixture)
        tde_prepare_empty_encrypted_fixture
        ;;
    prepare_rekey_reference_fixture)
        tde_prepare_rekey_reference_fixture
        ;;
    prepare_offline_decrypt_fixture)
        tde_prepare_offline_decrypt_fixture
        ;;
    prepare_snapshot_fixture)
        tde_prepare_snapshot_fixture
        ;;
    prepare_all_plain_fixture)
        tde_prepare_all_plain_fixture
        ;;
    encrypt_tablespace)
        [ -n "${2:-}" ] || tde_fail "encrypt_tablespace requires a tablespace name."
        tde_encrypt_tablespace "$2"
        ;;
    rekey_tablespace)
        [ -n "${2:-}" ] || tde_fail "rekey_tablespace requires a tablespace name."
        tde_rekey_tablespace "$2"
        ;;
    decrypt_tablespace)
        [ -n "${2:-}" ] || tde_fail "decrypt_tablespace requires a tablespace name."
        tde_decrypt_tablespace "$2"
        ;;
    duplicate_keystore_rejected)
        tde_duplicate_keystore_rejected
        ;;
    duplicate_master_key_rejected)
        tde_duplicate_master_key_rejected
        ;;
    negative_wrap_key)
        tde_negative_wrap_key
        ;;
    negative_invalid_keystore)
        tde_negative_invalid_keystore
        ;;
    negative_invalid_keystore_version)
        tde_negative_invalid_keystore_version
        ;;
    negative_invalid_keystore_missing_active)
        tde_negative_invalid_keystore_missing_active
        ;;
    negative_missing_master_key)
        tde_negative_missing_master_key
        ;;
    negative_corrupted_wrapped_tbs_key)
        tde_negative_corrupted_wrapped_tbs_key
        ;;
    negative_corrupted_header_master_key_id)
        tde_negative_corrupted_header_master_key_id
        ;;
    negative_autoload_off)
        tde_negative_autoload_off
        ;;
    plain_only_autoload_off_ok)
        tde_plain_only_autoload_off_ok
        ;;
    all_decrypted_autoload_off_ok)
        tde_all_decrypted_autoload_off_ok
        ;;
    negative_rotated_key_history)
        tde_negative_rotated_key_history
        ;;
    negative_online_operation)
        tde_negative_online_operation
        ;;
    negative_invalid_state)
        tde_negative_invalid_state
        ;;
    snapshot_backup_pre_post_rotate)
        tde_snapshot_backup_pre_post_rotate
        ;;
    snapshot_restore_old_history_ok)
        tde_snapshot_restore_old_history_ok
        ;;
    snapshot_restore_old_history_missing_key_fail)
        tde_snapshot_restore_old_history_missing_key_fail
        ;;
    decrypt_all_and_restart)
        tde_decrypt_all_and_restart
        ;;
    repro_rekey_metadata_mismatch)
        tde_repro_rekey_metadata_mismatch
        ;;
    *)
        tde_fail "unknown action: ${1:-<empty>}"
        ;;
esac
