# shellcheck shell=bash
# Optional. Sourced by `ops restore-test` with a restored copy in $RESTORE_DIR.
# Fail (non-zero) when the copy is unusable.

test -d "$RESTORE_DIR/data"
