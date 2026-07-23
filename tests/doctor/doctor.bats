#!/usr/bin/env bats

@test "Codex MCP onboarding and doctor obey the security contract" {
  run bash "$BATS_TEST_DIRNAME/run-shell-tests.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS: MCP onboarding and doctor security tests"* ]]
}
