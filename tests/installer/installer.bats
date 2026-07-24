#!/usr/bin/env bats

load helpers

setup() {
  make_fixture_release
}

teardown() {
  remove_fixture_release
}

@test "default target installs both Claude and Codex payloads" {
  run run_fixture_installer
  [ "$status" -eq 0 ]
  [ -f "$FIXTURE_HOME/.claude/agents/harness-coordinator.md" ]
  [ -f "$FIXTURE_HOME/.deepwind/install/share/codex-marketplace/plugins/deepwind-harness/.codex-plugin/plugin.json" ]
  [ -f "$FIXTURE_HOME/.deepwind/install/share/codex-marketplace/.agents/plugins/marketplace.json" ]
  [ ! -e "$FIXTURE_HOME/codex-plugin-calls" ]
}

@test "explicit plugin opt-in enables the release-contained Codex plugin with fixed argv" {
  write_fixture_codex_lifecycle_stub

  run run_fixture_installer --target codex --enable-codex-plugin
  [ "$status" -eq 0 ]
  expected_marketplace="$FIXTURE_HOME/.deepwind/install/share/codex-marketplace"
  [ "$(sed -n '1p' "$FIXTURE_HOME/codex-plugin-calls")" = "plugin marketplace list --json" ]
  [ "$(sed -n '2p' "$FIXTURE_HOME/codex-plugin-calls")" = "plugin marketplace list --json" ]
  [ "$(sed -n '3p' "$FIXTURE_HOME/codex-plugin-calls")" = "plugin marketplace add $expected_marketplace --json" ]
  [ "$(sed -n '4p' "$FIXTURE_HOME/codex-plugin-calls")" = "plugin add deepwind-harness@deepwind --json" ]
  [ "$(sed -n '5p' "$FIXTURE_HOME/codex-plugin-calls")" = "plugin marketplace list --json" ]
  [ "$(sed -n '6p' "$FIXTURE_HOME/codex-plugin-calls")" = "plugin list --json" ]

  : > "$FIXTURE_HOME/codex-plugin-calls"
  run run_fixture_installer --target codex --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"plugin: enabled (deepwind-harness@deepwind 1.2.3)"* ]]
  [ "$(cat "$FIXTURE_HOME/codex-plugin-calls")" = $'plugin marketplace list --json\nplugin list --json' ]
}

@test "plugin opt-in preserves a conflicting configured marketplace" {
  write_fixture_codex_lifecycle_stub
  printf '%s' "$FIXTURE_HOME/user-owned-marketplace" \
    > "$FIXTURE_HOME/.fixture-codex-marketplace"

  run run_fixture_installer --target codex --enable-codex-plugin
  [ "$status" -eq 2 ]
  [[ "$output" == *"configured DeepWind marketplace points outside the verified release"* ]]
  [ "$(cat "$FIXTURE_HOME/.fixture-codex-marketplace")" = "$FIXTURE_HOME/user-owned-marketplace" ]
  [ "$(cat "$FIXTURE_HOME/codex-plugin-calls")" = "plugin marketplace list --json" ]
  [ ! -e "$FIXTURE_HOME/.codex/agents/harness-coordinator.toml" ]
  [ ! -e "$FIXTURE_HOME/.deepwind/install/state.tsv" ]
}

@test "check gives an actionable state when the Codex plugin was not opted in" {
  write_fixture_codex_lifecycle_stub
  run run_fixture_installer --target codex
  [ "$status" -eq 0 ]

  run run_fixture_installer --target codex --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"plugin: not-enabled"* ]]
  [[ "$output" == *"--enable-codex-plugin"* ]]
}

@test "target accepts only claude, codex, or both" {
  run run_fixture_installer --target invalid
  [ "$status" -eq 2 ]
  [ ! -e "$FIXTURE_HOME/.claude" ]
  [ ! -e "$FIXTURE_HOME/.codex" ]
}

@test "bad archive digest aborts before destination mutation" {
  printf 'tampered\n' >> "$FIXTURE_RELEASE/deepwind-harness-codex-v1.2.3.tar.gz"
  run run_fixture_installer
  [ "$status" -ne 0 ]
  [ ! -e "$FIXTURE_HOME/.claude" ]
  [ ! -e "$FIXTURE_HOME/.codex" ]
}

@test "manifest without the versioned bootstrap contract is rejected" {
  jq 'del(.bootstrap)' "$FIXTURE_RELEASE/deepwind-release-manifest.json" \
    > "$FIXTURE_RELEASE/deepwind-release-manifest.json.next"
  mv "$FIXTURE_RELEASE/deepwind-release-manifest.json.next" \
    "$FIXTURE_RELEASE/deepwind-release-manifest.json"
  run run_fixture_installer
  [ "$status" -ne 0 ]
  [ ! -e "$FIXTURE_HOME/.claude" ]
  [ ! -e "$FIXTURE_HOME/.codex" ]
}

@test "dry run writes no destination or state files" {
  run run_fixture_installer --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_HOME/.claude" ]
  [ ! -e "$FIXTURE_HOME/.codex" ]
  [ ! -e "$FIXTURE_HOME/.deepwind" ]
}

@test "modified managed file is retained without force" {
  run run_fixture_installer
  [ "$status" -eq 0 ]
  printf 'user edit\n' > "$FIXTURE_HOME/.claude/agents/harness-coordinator.md"
  run run_fixture_installer --target claude
  [ "$status" -eq 0 ]
  [ "$(cat "$FIXTURE_HOME/.claude/agents/harness-coordinator.md")" = "user edit" ]
}

@test "second-target failure rolls back the first target" {
  run env \
    HOME="$FIXTURE_HOME" \
    PATH="$FIXTURE_ROOT/bin:$PATH" \
    DEEPWIND_INSTALL_TESTING=1 \
    DEEPWIND_TEST_FAIL_TARGET=codex \
    DEEPWIND_RELEASE_DIR="$FIXTURE_RELEASE" \
    bash "$FIXTURE_INSTALLER" --version 1.2.3
  [ "$status" -ne 0 ]
  [ ! -e "$FIXTURE_HOME/.claude/agents/harness-coordinator.md" ]
  [ ! -e "$FIXTURE_HOME/.deepwind/install/share/codex-marketplace/plugins/deepwind-harness/.codex-plugin/plugin.json" ]
}

@test "standalone script works through the documented pipe invocation" {
  run bash -c \
    'cat "$1" | env HOME="$2" PATH="$4:$PATH" DEEPWIND_INSTALL_TESTING=1 DEEPWIND_RELEASE_DIR="$3" bash -s -- --version 1.2.3' \
    _ "$FIXTURE_INSTALLER" "$FIXTURE_HOME" "$FIXTURE_RELEASE" "$FIXTURE_ROOT/bin"
  [ "$status" -eq 0 ]
  [ -f "$FIXTURE_HOME/.claude/agents/harness-coordinator.md" ]
  [ -f "$FIXTURE_HOME/.codex/agents/harness-coordinator.toml" ]
}

@test "interrupt after mutation rolls back and exits nonzero" {
  run env \
    HOME="$FIXTURE_HOME" \
    PATH="$FIXTURE_ROOT/bin:$PATH" \
    DEEPWIND_INSTALL_TESTING=1 \
    DEEPWIND_TEST_INTERRUPT_AFTER_MUTATIONS=1 \
    DEEPWIND_RELEASE_DIR="$FIXTURE_RELEASE" \
    bash "$FIXTURE_INSTALLER" --version 1.2.3
  [ "$status" -ne 0 ]
  [ ! -e "$FIXTURE_HOME/.claude" ]
  [ ! -e "$FIXTURE_HOME/.deepwind" ]
}

@test "signature failure aborts before destination mutation" {
  printf 'BAD-SIGNATURE\n' > "$FIXTURE_RELEASE/deepwind-release-manifest.json.asc"
  run run_fixture_installer
  [ "$status" -ne 0 ]
  [ ! -e "$FIXTURE_HOME/.claude" ]
  [ ! -e "$FIXTURE_HOME/.codex" ]
}

@test "committed installer is generated with the active trusted keyring" {
  generated="$FIXTURE_ROOT/generated-installer.sh"
  run bash "$TEST_ROOT/release/build-installer.sh" "$generated"
  [ "$status" -eq 0 ]
  run cmp "$TEST_ROOT/deepwind-init.sh" "$generated"
  [ "$status" -eq 0 ]
  run grep -Eq "^EMBEDDED_TRUSTED_KEYRING_B64='[^']+'$" \
    "$TEST_ROOT/deepwind-init.sh"
  [ "$status" -eq 0 ]
}

@test "release matrix covers transitions rollback boundaries and fixture containment" {
  run bash "$BATS_TEST_DIRNAME/matrix-contract.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS: installer macOS/Linux release matrix contract"* ]]
}
