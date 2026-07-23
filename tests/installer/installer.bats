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

@test "published installer has no runtime unsigned-test bypass" {
  run env \
    HOME="$FIXTURE_HOME" \
    PATH="$FIXTURE_ROOT/bin:$PATH" \
    DEEPWIND_INSTALL_TESTING=1 \
    DEEPWIND_RELEASE_DIR="$FIXTURE_RELEASE" \
    bash "$TEST_ROOT/deepwind-init.sh" --version 1.2.3
  [ "$status" -ne 0 ]
  [[ "$output" == *"no trusted release keyring is embedded"* ]]
  [ ! -e "$FIXTURE_HOME/.claude" ]
  [ ! -e "$FIXTURE_HOME/.codex" ]
}
