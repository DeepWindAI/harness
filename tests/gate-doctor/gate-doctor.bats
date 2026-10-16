#!/usr/bin/env bats

@test "gate-doctor.sh preflight checks are correct and never crash" {
  run bash "$BATS_TEST_DIRNAME/run-shell-tests.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS: gate-doctor.sh preflight tests"* ]]
}
