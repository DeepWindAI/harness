#!/usr/bin/env bash
# Static contract for the credential-free portion of the release workflow.
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
WORKFLOW="$ROOT/.github/workflows/weekly-release.yml"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/deepwind-workflow-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() {
  grep -F -- "$1" "$WORKFLOW" >/dev/null || fail "workflow is missing: $1"
}

require_literal 'BOOTSTRAP="$ASSETS/deepwind-init-v${VERSION_FROM_TAG}.sh"'
require_literal 'bash release/build-installer.sh "$BOOTSTRAP"'
require_literal '--bootstrap "$BOOTSTRAP"'
require_literal 'sha256sum deepwind-* public-keyring.json'
require_literal 'test -s "$BOOTSTRAP"'

# The release filename varies only by version; the bytes are reproducible from
# the same tagged tree and never fetch executable content from a branch.
bash "$ROOT/release/build-installer.sh" "$TMP/deepwind-init-v1.2.3.sh"
bash "$ROOT/release/build-installer.sh" "$TMP/deepwind-init-v1.2.3-again.sh"
cmp "$TMP/deepwind-init-v1.2.3.sh" "$TMP/deepwind-init-v1.2.3-again.sh" \
  || fail 'same tagged tree did not produce a byte-identical bootstrap'
test -x "$TMP/deepwind-init-v1.2.3.sh" || fail 'generated bootstrap is not executable'

if grep -Eq \
  'raw[.]githubusercontent[.]com/[^ ]+/main/|/archive/refs/heads/main|/releases/download/main/' \
  "$WORKFLOW" "$TMP/deepwind-init-v1.2.3.sh"; then
  fail 'release contract contains a mutable-main asset URL'
fi

printf 'PASS: versioned bootstrap release workflow contract\n'
