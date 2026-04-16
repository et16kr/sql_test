# MRDB TDE Phase 1 SQL Suite

This suite validates the Altibase MRDB TDE phase 1 slice with the local
`sql_test` runner.

Covered scope:

- `ALTER SYSTEM TDE CREATE KEYSTORE`
- `ALTER SYSTEM TDE CREATE MASTER KEY`
- `CREATE MEMORY TABLESPACE ... ENCRYPTION`
- `V$TABLESPACES` visibility
- restart auto-load
- startup failure for invalid wrap key / invalid keystore /
  missing master key history / `TDE_AUTO_LOAD=0`

Out of scope:

- DRDB
- rotate / rekey
- existing tablespace encrypt / decrypt
- redo encryption

## Preconditions

- Run from the `sql_test` repository root.
- `is` and `server` must be available in `PATH`.
- `ALTIBASE_HOME` must be set.
- `TDE_KEYSTORE_PATH` and `TDE_WRAP_KEY_PATH` in `altibase.properties`
  must already point to a dedicated test path.
- The suite is intentionally standalone and is not included in
  `tests/tests.ts`.

The helper guards against obviously unsafe paths. By default, paths under
`/tmp/` or paths containing `sql_test`, `tde_test`, or `tde-test` are treated
as test-dedicated. If you really need to use a different path, set:

```bash
export SQL_TEST_TDE_ALLOW_UNSAFE_PATH=1
```

## Recommended Run

```bash
./bin/altitest tests/tde/tde.ts --server-mode none --continue-on-error
```

## Notes

- The suite shares one server-wide TDE fixture across ordered cases.
- Negative cases restore the original file state before returning success.
- No new `sql_test` directive or runner feature is required for this suite.
- Manual reference used in SQL comments:
  `doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md`
