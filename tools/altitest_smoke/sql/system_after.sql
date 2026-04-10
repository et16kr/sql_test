--CASE:STATE SET system_after_visible
SELECT 1;
--+SET_ENV ALTI_FAKE_MARK=AFTER;
--+SYSTEM sh -c '[ "$ALTI_FAKE_MARK" = "AFTER" ] && [ -f "${TMPDIR:-/tmp}/altitest_smoke_state/system_after_visible" ]';
