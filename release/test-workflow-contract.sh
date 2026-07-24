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
require_in() {
  file="$1"
  literal="$2"
  grep -F -- "$literal" "$file" >/dev/null \
    || fail "$(basename "$file") is missing: $literal"
}
job_block() {
  file="$1"
  job="$2"
  awk -v marker="  ${job}:" '
    $0 == marker { found=1 }
    found && $0 != marker && /^  [[:alnum:]_-]+:/ { exit }
    found { print }
  ' "$file"
}
require_job_literal() {
  file="$1"
  job="$2"
  literal="$3"
  job_block "$file" "$job" | grep -F -- "$literal" >/dev/null \
    || fail "$(basename "$file") job $job is missing: $literal"
}

require_literal 'BOOTSTRAP="$ASSETS/deepwind-init-v${VERSION_FROM_TAG}.sh"'
require_literal 'bash release/build-installer.sh "$BOOTSTRAP"'
require_literal '--bootstrap "$BOOTSTRAP"'
require_literal 'sha256sum deepwind-* public-keyring.json'
require_literal 'test -s "$BOOTSTRAP"'
require_literal 'bash release/scan-release-archives.sh'
require_literal '--prerelease --latest=false'

# The release-producing workflow is fail-closed: both tag pushes and automated
# bump paths must pass the portable matrix before build-and-release can start.
require_job_literal "$WORKFLOW" build-and-release 'needs: [ bump-and-release, installer-matrix ]'
require_job_literal "$WORKFLOW" build-and-release "needs.installer-matrix.result == 'success' &&"
matrix_guard_line=$(job_block "$WORKFLOW" build-and-release \
  | grep -nF "needs.installer-matrix.result == 'success' &&" | cut -d: -f1)
push_path_line=$(job_block "$WORKFLOW" build-and-release \
  | grep -nF "github.event_name == 'push' ||" | cut -d: -f1)
if [ -z "$matrix_guard_line" ] || [ -z "$push_path_line" ] \
  || [ "$matrix_guard_line" -ge "$push_path_line" ]; then
  fail 'tag-push release path can bypass the installer matrix'
fi

# Least privilege belongs at job scope. Test-only matrix jobs never retain a
# credential helper, while only bump/release jobs receive contents:write.
require_in "$WORKFLOW" 'permissions:'
top_permissions=$(awk '
  $0 == "permissions:" { found=1; next }
  found && /^[^ ]/ { exit }
  found { print }
' "$WORKFLOW")
printf '%s\n' "$top_permissions" | grep -F 'contents: read' >/dev/null \
  || fail 'weekly-release top-level permissions are not read-only'
if printf '%s\n' "$top_permissions" | grep -F 'contents: write' >/dev/null; then
  fail 'weekly-release grants contents:write globally'
fi
require_job_literal "$WORKFLOW" bump-and-release 'contents: write'
require_job_literal "$WORKFLOW" installer-matrix 'contents: read'
require_job_literal "$WORKFLOW" installer-matrix 'persist-credentials: false'
require_job_literal "$WORKFLOW" build-and-release 'contents: write'
require_job_literal "$INSTALLER_WORKFLOW" installer-matrix 'contents: read'
require_job_literal "$INSTALLER_WORKFLOW" installer-matrix 'persist-credentials: false'

# Supply-chain actions are immutable and the PR gate covers every Codex
# distribution input plus its policy/doctor/docs tests.
for workflow_file in "$WORKFLOW" "$INSTALLER_WORKFLOW"; do
  require_in "$workflow_file" \
    'uses: actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09 # v5'
  require_in "$workflow_file" \
    'uses: rhysd/actionlint@03d0035246f3e81f36aed592ffb4bebf33a03106 # v1.7.7'
  require_in "$workflow_file" 'bash tests/plugin/test-codex-plugin.sh'
  require_in "$workflow_file" 'bash tests/plugin/assert-child-mcp-policy.sh'
  require_in "$workflow_file" 'bash tests/plugin/test-codex-plugin-lifecycle.sh'
  require_in "$workflow_file" 'bash tests/doctor/run-shell-tests.sh'
  require_in "$workflow_file" 'bash tests/docs/test-installation-docs.sh'
done
for path_filter in \
  "- '.agents/**'" \
  "- 'plugins/**'" \
  "- 'codex/**'" \
  "- 'config/channels/**'" \
  "- 'tests/plugin/**'" \
  "- 'tests/doctor/**'" \
  "- 'tests/docs/**'"; do
  require_in "$INSTALLER_WORKFLOW" "$path_filter"
done

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
