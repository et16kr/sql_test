./initialize.sql | timeout_sec=600
./bootstrap/bootstrap.ts
./admin_negative/admin_negative.ts
./basic/basic.ts
./restart/restart.ts
./startup_negative/startup_negative.ts
./extended/extended.ts
./rotate/rotate.ts
./offline_encrypt/offline_encrypt.ts
./rekey/rekey.ts
./offline_decrypt/offline_decrypt.ts
./invalid_state/invalid_state.ts
./snapshot/snapshot.ts
./security_metadata/security_metadata.ts
./ciphertext/ciphertext.ts
./crash/crash.ts
./log/log.ts
./final/final.ts
./finalize.sql | timeout_sec=600
