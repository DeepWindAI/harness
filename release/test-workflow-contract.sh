#!/usr/bin/env bash
# Static contract for the credential-free portion of the release workflow.
# shellcheck disable=SC2016
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
WORKFLOW="$ROOT/.github/workflows/weekly-release.yml"
INSTALLER_WORKFLOW="$ROOT/.github/workflows/installer.yml"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/deepwind-workflow-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_literal() {
  grep -F -- "$1" "$WORKFLOW" >/dev/null || fail "workflow is missing: $1"
}

require_supported_macos_runner() {
  local workflow=$1

  grep -F -- 'os: macos-15' "$workflow" >/dev/null \
    || fail "$(basename -- "$workflow") must use macos-15"
  if grep -F -- 'macos-13' "$workflow" >/dev/null; then
    fail "$(basename -- "$workflow") must not use retired macos-13"
  fi
}

# GitHub retired macos-13. Keep testing Bash 3.2 semantics by naming the
# matrix entry that way, while running it on the supported macos-15 image.
require_supported_macos_runner "$WORKFLOW"
require_supported_macos_runner "$INSTALLER_WORKFLOW"

require_literal 'BOOTSTRAP="$ASSETS/deepwind-init-v${VERSION_FROM_TAG}.sh"'
require_literal 'bash release/build-installer.sh "$BOOTSTRAP"'
require_literal '--bootstrap "$BOOTSTRAP"'
require_literal 'sha256sum deepwind-* public-keyring.json'
require_literal 'test -s "$BOOTSTRAP"'
require_literal 'bash release/scan-release-archives.sh'
require_literal '--prerelease --latest=false'

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

tar -C "$ROOT" -czf "$TMP/deepwind-harness-claude-v1.2.3.tar.gz" \
  agents skills frameworks payload CLAUDE.md.starter LICENSE VERSION
tar -C "$ROOT" -czf "$TMP/deepwind-harness-codex-v1.2.3.tar.gz" \
  .agents/plugins/marketplace.json plugins/deepwind-harness codex/agents LICENSE VERSION
bash "$ROOT/release/scan-release-archives.sh" \
  "$TMP/deepwind-harness-claude-v1.2.3.tar.gz" \
  "$TMP/deepwind-harness-codex-v1.2.3.tar.gz" >/dev/null \
  || fail 'current release archive sources contain mutable or obsolete references'

mkdir "$TMP/bad-archive"
printf '%s\n' 'https://raw.githubusercontent.com/DeepWindAI/harness/main/VERSION' \
  > "$TMP/bad-archive/legacy.txt"
tar -C "$TMP/bad-archive" -czf "$TMP/deepwind-harness-bad-v1.2.3.tar.gz" legacy.txt
if bash "$ROOT/release/scan-release-archives.sh" \
  "$TMP/deepwind-harness-bad-v1.2.3.tar.gz" >/dev/null 2>&1; then
  fail 'archive scanner accepted a mutable-main reference'
fi

printf 'PASS: versioned bootstrap release workflow contract\n'
