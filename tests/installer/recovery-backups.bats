#!/usr/bin/env bats

@test "forced replacement recovery backups satisfy the retention contract" {
  run bash "$BATS_TEST_DIRNAME/recovery-backups.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS: forced replacement recovery backup contract"* ]]
}
