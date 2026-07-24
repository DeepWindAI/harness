#!/usr/bin/env bash
# Portable release-matrix contract. Bats wraps this in CI; keeping assertions
# compatible with stock macOS Bash 3.2 enables local reproduction.
# shellcheck disable=SC2016
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=tests/installer/helpers.bash
. "$ROOT/helpers.bash"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_file() { [ -f "$1" ] || fail "missing file: $1"; }
assert_absent() { [ ! -e "$1" ] || fail "unexpected path: $1"; }

new_fixture() {
  make_fixture_release
  FIXTURE_OUTSIDE="$FIXTURE_ROOT/outside"
  mkdir -p "$FIXTURE_OUTSIDE"
  printf 'do-not-touch\n' > "$FIXTURE_OUTSIDE/sentinel"
  FIXTURE_OUTSIDE_DIGEST=$(test_sha256 "$FIXTURE_OUTSIDE/sentinel")
}

assert_fixture_boundary() {
  [ "$(test_sha256 "$FIXTURE_OUTSIDE/sentinel")" = "$FIXTURE_OUTSIDE_DIGEST" ] \
    || fail 'installer changed a path outside fixture HOME'
  assert_absent "$FIXTURE_HOME/.deepwind-test-tool-invocations"
}

assert_clean_rollback() {
  assert_absent "$FIXTURE_HOME/.claude/agents/harness-coordinator.md"
  assert_absent "$FIXTURE_HOME/.codex/agents/harness-coordinator.toml"
  assert_absent "$FIXTURE_HOME/.deepwind/install"
}

# RED until DW-006 creates the required pinned release gate.
assert_file "$TEST_ROOT/.github/workflows/installer.yml"

new_fixture
mkdir -p "$FIXTURE_HOME/.mcp-auth" "$FIXTURE_HOME/.claude/hooks"
printf 'oauth-sentinel-not-a-token\n' > "$FIXTURE_HOME/.mcp-auth/cache"
printf 'legacy-hook\n' > "$FIXTURE_HOME/.claude/hooks/custom-hook.sh"
printf 'legacy-config\n' > "$FIXTURE_HOME/.claude.json"
oauth_digest=$(test_sha256 "$FIXTURE_HOME/.mcp-auth/cache")
run_fixture_installer >/dev/null
assert_file "$FIXTURE_HOME/.claude/agents/harness-coordinator.md"
assert_file "$FIXTURE_HOME/.codex/agents/harness-coordinator.toml"
[ "$(test_sha256 "$FIXTURE_HOME/.mcp-auth/cache")" = "$oauth_digest" ] || fail 'OAuth cache changed'
[ "$(cat "$FIXTURE_HOME/.claude/hooks/custom-hook.sh")" = legacy-hook ] || fail 'legacy Claude hook changed'
[ "$(cat "$FIXTURE_HOME/.claude.json")" = legacy-config ] || fail 'legacy Claude config changed'
assert_fixture_boundary
remove_fixture_release

# Target transitions never cross-install or delete the other target.
new_fixture
run_fixture_installer --target claude >/dev/null
assert_file "$FIXTURE_HOME/.claude/agents/harness-coordinator.md"
assert_absent "$FIXTURE_HOME/.codex"
run_fixture_installer --target both >/dev/null
assert_file "$FIXTURE_HOME/.codex/agents/harness-coordinator.toml"
run_fixture_installer --target claude >/dev/null
assert_file "$FIXTURE_HOME/.codex/agents/harness-coordinator.toml"
assert_fixture_boundary
remove_fixture_release

new_fixture
run_fixture_installer --target codex >/dev/null
assert_file "$FIXTURE_HOME/.codex/agents/harness-coordinator.toml"
assert_absent "$FIXTURE_HOME/.claude/agents/harness-coordinator.md"
run_fixture_installer --target both >/dev/null
assert_file "$FIXTURE_HOME/.claude/agents/harness-coordinator.md"
assert_fixture_boundary
remove_fixture_release

# A tracked payload moves forward/back while a user edit remains preserved.
new_fixture
run_fixture_installer --target claude >/dev/null
printf 'claude-agent-v2\n' > "$FIXTURE_RELEASE/claude/agents/harness-coordinator.md"
refresh_claude_fixture_archive
run_fixture_installer --target claude >/dev/null
[ "$(cat "$FIXTURE_HOME/.claude/agents/harness-coordinator.md")" = claude-agent-v2 ] || fail 'upgrade did not replace tracked file'
printf 'claude-agent-v1\n' > "$FIXTURE_RELEASE/claude/agents/harness-coordinator.md"
refresh_claude_fixture_archive
run_fixture_installer --target claude >/dev/null
[ "$(cat "$FIXTURE_HOME/.claude/agents/harness-coordinator.md")" = claude-agent-v1 ] || fail 'downgrade did not replace tracked file'
printf 'user-edit\n' > "$FIXTURE_HOME/.claude/agents/harness-coordinator.md"
printf 'claude-agent-v3\n' > "$FIXTURE_RELEASE/claude/agents/harness-coordinator.md"
refresh_claude_fixture_archive
run_fixture_installer --target claude >/dev/null
[ "$(cat "$FIXTURE_HOME/.claude/agents/harness-coordinator.md")" = user-edit ] || fail 'modified managed file was overwritten'
assert_fixture_boundary
remove_fixture_release

# Interrupt every actual mutation boundary. Counting state entries keeps this
# test aligned when the release-owned install plan grows.
new_fixture
run_fixture_installer >/dev/null
mutation_count=$(wc -l < "$FIXTURE_HOME/.deepwind/install/state.tsv" | tr -d '[:space:]')
remove_fixture_release
mutation=1
while [ "$mutation" -le "$mutation_count" ]; do
  new_fixture
  if env HOME="$FIXTURE_HOME" TMPDIR="$FIXTURE_HOME/tmp" PATH="$FIXTURE_ROOT/bin:$PATH" \
    DEEPWIND_INSTALL_TESTING=1 DEEPWIND_TEST_INTERRUPT_AFTER_MUTATIONS="$mutation" \
    DEEPWIND_RELEASE_DIR="$FIXTURE_RELEASE" bash "$FIXTURE_INSTALLER" --version 1.2.3 >/dev/null 2>&1; then
    fail "interrupt at mutation $mutation succeeded"
  fi
  assert_clean_rollback
  assert_fixture_boundary
  remove_fixture_release
  mutation=$((mutation + 1))
done

# Payload substitution and a concurrent lock holder abort before mutation.
new_fixture
printf 'swapped-payload\n' >> "$FIXTURE_RELEASE/deepwind-harness-codex-v1.2.3.tar.gz"
if run_fixture_installer >/dev/null 2>&1; then fail 'swapped archive was accepted'; fi
assert_clean_rollback
assert_fixture_boundary
remove_fixture_release

new_fixture
(
  mkdir "$FIXTURE_HOME/.deepwind-install.lock"
  printf ready > "$FIXTURE_HOME/lock-ready"
  sleep 1
  rmdir "$FIXTURE_HOME/.deepwind-install.lock"
) &
lock_holder=$!
while [ ! -f "$FIXTURE_HOME/lock-ready" ]; do sleep 0.05; done
if run_fixture_installer >/dev/null 2>&1; then fail 'concurrent lock holder was ignored'; fi
wait "$lock_holder"
run_fixture_installer >/dev/null
assert_fixture_boundary
remove_fixture_release

# jq/curl are explicit prerequisites; wget/openssl intentionally are not.
grep -F 'need_command jq' "$TEST_ROOT/deepwind-init.sh" >/dev/null || fail 'jq preflight missing'
grep -F 'need_command curl' "$TEST_ROOT/deepwind-init.sh" >/dev/null || fail 'curl preflight missing'
if grep -Eq 'need_command (wget|openssl)' "$TEST_ROOT/deepwind-init.sh"; then
  fail 'installer unexpectedly requires wget or openssl'
fi
grep -F '$DEEPWIND_INSTALL_DIR/share/claude/VERSION' \
  "$TEST_ROOT/payload/bin/deepwind" >/dev/null \
  || fail 'DeepWind CLI does not read the installed Claude target version'
grep -F '$DEEPWIND_INSTALL_DIR/share/codex/VERSION' \
  "$TEST_ROOT/payload/bin/deepwind" >/dev/null \
  || fail 'DeepWind CLI does not read the installed Codex target version'
grep -F '$HOME/.deepwind/install/share/claude/VERSION' \
  "$TEST_ROOT/payload/hooks/session-start-deepwind-version-check.sh" >/dev/null \
  || fail 'Claude hook does not read its installed target version'

printf 'PASS: installer macOS/Linux release matrix contract\n'
