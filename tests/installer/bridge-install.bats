#!/usr/bin/env bats
# The bridge CLI install is best-effort and strictly post-transaction: it must
# never touch the signed release install it follows. These tests stub node
# and npm so the outcome is deterministic regardless of what is actually
# installed on the machine running the suite.

load helpers

setup() {
  make_fixture_release
}

teardown() {
  remove_fixture_release
}

@test "--with-bridge invokes npm install for the bridge package after a real install" {
  write_fixture_node_stub 22
  write_fixture_npm_stub success

  run run_fixture_installer --with-bridge
  [ "$status" -eq 0 ]
  [ -f "$FIXTURE_HOME/.claude/agents/harness-coordinator.md" ]
  [ -f "$FIXTURE_HOME/npm-calls" ]
  [ "$(cat "$FIXTURE_HOME/npm-calls")" = 'i -g @deepwind/bridge' ]
  [[ "$output" == *"DeepWind bridge CLI installed"* ]]
  [[ "$output" == *"pm33-bridge login && pm33-bridge register"* ]]
}

@test "a failing npm warns, exits 0, and leaves installed files identical to a run without the flag" {
  run run_fixture_installer
  [ "$status" -eq 0 ]
  # state.tsv records absolute paths under the per-test mktemp FIXTURE_HOME,
  # which differs across the two fixture instances below; normalize it away
  # so the comparison reflects only the managed-file set and digests.
  baseline_state=$(sed "s#$FIXTURE_HOME#FIXTURE_HOME#g" "$FIXTURE_HOME/.deepwind/install/state.tsv")
  baseline_role=$(cat "$FIXTURE_HOME/.claude/agents/harness-coordinator.md")
  remove_fixture_release
  make_fixture_release

  write_fixture_node_stub 22
  write_fixture_npm_stub failure

  run run_fixture_installer --with-bridge
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: bridge install failed"*"npm/network"* ]]
  [[ "$output" == *"npm i -g @deepwind/bridge"* ]]
  [ -f "$FIXTURE_HOME/npm-calls" ]

  with_bridge_state=$(sed "s#$FIXTURE_HOME#FIXTURE_HOME#g" "$FIXTURE_HOME/.deepwind/install/state.tsv")
  with_bridge_role=$(cat "$FIXTURE_HOME/.claude/agents/harness-coordinator.md")
  [ "$baseline_state" = "$with_bridge_state" ]
  [ "$baseline_role" = "$with_bridge_role" ]
}

@test "omitting --with-bridge never invokes npm" {
  write_fixture_node_stub 22
  write_fixture_npm_stub success

  run run_fixture_installer
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_HOME/npm-calls" ]
}

@test "--with-bridge cannot be combined with --dry-run or --check" {
  run run_fixture_installer --with-bridge --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"--with-bridge cannot be combined with --dry-run or --check"* ]]
  [ ! -e "$FIXTURE_HOME/.claude" ]
  [ ! -e "$FIXTURE_HOME/.deepwind" ]

  run run_fixture_installer --with-bridge --check
  [ "$status" -eq 2 ]
  [[ "$output" == *"--with-bridge cannot be combined with --dry-run or --check"* ]]
}

@test "usage documents --with-bridge" {
  run run_fixture_installer -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"--with-bridge"* ]]
}

@test "--with-bridge wraps the npm install with the portable timeout helper when timeout is available" {
  write_fixture_node_stub 22
  write_fixture_npm_stub success
  write_fixture_timeout_stub

  run run_fixture_installer --with-bridge
  [ "$status" -eq 0 ]
  [ -f "$FIXTURE_HOME/timeout-calls" ]
  [ "$(cat "$FIXTURE_HOME/timeout-calls")" = '120 npm i -g @deepwind/bridge' ]
  [ -f "$FIXTURE_HOME/npm-calls" ]
  [ "$(cat "$FIXTURE_HOME/npm-calls")" = 'i -g @deepwind/bridge' ]
  [[ "$output" == *"DeepWind bridge CLI installed"* ]]
}

@test "--with-bridge still installs the bridge when no timeout binary exists on PATH" {
  write_fixture_node_stub 22
  write_fixture_npm_stub success

  run run_fixture_installer_without_timeout --with-bridge
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_HOME/timeout-calls" ]
  [ -f "$FIXTURE_HOME/npm-calls" ]
  [ "$(cat "$FIXTURE_HOME/npm-calls")" = 'i -g @deepwind/bridge' ]
  [[ "$output" == *"DeepWind bridge CLI installed"* ]]
}

@test "a timeout-wrapped npm failure warns, exits 0, and leaves installed files identical to a run without the flag" {
  run run_fixture_installer
  [ "$status" -eq 0 ]
  baseline_state=$(sed "s#$FIXTURE_HOME#FIXTURE_HOME#g" "$FIXTURE_HOME/.deepwind/install/state.tsv")
  baseline_role=$(cat "$FIXTURE_HOME/.claude/agents/harness-coordinator.md")
  remove_fixture_release
  make_fixture_release

  write_fixture_node_stub 22
  write_fixture_npm_stub failure
  write_fixture_timeout_stub

  run run_fixture_installer --with-bridge
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: bridge install failed"*"npm/network, or timed out"* ]]
  [ -f "$FIXTURE_HOME/timeout-calls" ]
  [ "$(cat "$FIXTURE_HOME/timeout-calls")" = '120 npm i -g @deepwind/bridge' ]

  with_bridge_state=$(sed "s#$FIXTURE_HOME#FIXTURE_HOME#g" "$FIXTURE_HOME/.deepwind/install/state.tsv")
  with_bridge_role=$(cat "$FIXTURE_HOME/.claude/agents/harness-coordinator.md")
  [ "$baseline_state" = "$with_bridge_state" ]
  [ "$baseline_role" = "$with_bridge_role" ]
}
