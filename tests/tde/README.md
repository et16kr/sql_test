# MRDB TDE SQL Suite

This suite mirrors the internal TDE test model more closely than the previous
numbered `init.sql/test.sql` chain.

## Execution Model

The root suite is explicit:

- `initialize.sql`
- one or more single-file tests under the grouped subdirectories
- `finalize.sql`

No grouped test depends on `test.sql -> init.sql` auto-discovery, and no
numbered case is required to run before another numbered case. When a test
needs extra fixture state, it calls `tests/tde/bin/tde_case.sh` directly.

## Layout

- `initialize.sql`, `finalize.sql`, `tde.ts`
- `bootstrap/`
- `admin_negative/`
- `basic/`
- `restart/`
- `startup_negative/`
- `extended/`
- `rotate/`
- `offline_encrypt/`
- `rekey/`
- `offline_decrypt/`
- `invalid_state/`
- `snapshot/`
- `final/`
- `bin/`

Each group directory contains only single-file `.sql` tests plus a matching
group `.ts` that can be used for focused debugging.

## Preconditions

- Run from the `sql_test` repository root.
- `is` and `server` must be available in `PATH`.
- `ALTIBASE_HOME` must be set.
- `TDE_KEYSTORE_PATH` and `TDE_WRAP_KEY_PATH` in `altibase.properties`
  must already point to a dedicated test path.
- The suite is intentionally standalone and is not included in `tests/tests.ts`.

The helper guards against obviously unsafe paths. By default, paths under
`/tmp/` or paths containing `sql_test`, `tde_test`, or `tde-test` are treated
as test-dedicated. If you really need to use a different path, set:

```bash
export SQL_TEST_TDE_ALLOW_UNSAFE_PATH=1
```

## Recommended Run

Run the whole mirror:

```bash
./bin/altitest tests/tde/tde.ts --server-mode none --continue-on-error
```

Run one focused flow:

```bash
./bin/altitest tests/tde/initialize.sql --server-mode none
./bin/altitest tests/tde/rotate/rotate_reference_count_check.sql --server-mode none
./bin/altitest tests/tde/finalize.sql --server-mode none
```

Run one grouped slice after the standard lifecycle when you want several
related cases together:

```bash
./bin/altitest tests/tde/initialize.sql --server-mode none
./bin/altitest tests/tde/rotate/rotate.ts --server-mode none --continue-on-error
./bin/altitest tests/tde/finalize.sql --server-mode none
```

## Notes

- Negative cases restore the original file state before returning success.
- `rekey/rekey_metadata_mismatch_repro.sql` is a standalone repro/regression
  case for the reviewed metadata-mismatch bug and is intentionally excluded
  from `tde.ts`.
- Snapshot coverage is implemented with helper-driven checkpoint-image copies
  under the dedicated test path so the suite can stay standalone.
- Manual reference used in SQL comments:
  `doc/altibase-docs/Manuals/Altibase_trunk/eng/iSQL User's Manual.md`
