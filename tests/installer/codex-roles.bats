#!/usr/bin/env bats

load helpers

setup() {
  make_fixture_release
}

teardown() {
  remove_fixture_release
}

@test "installer exposes the bounded Codex role adapter" {
  run rg -q '^install_codex_roles\(\)' "$TEST_ROOT/lib/install-target.sh"
  [ "$status" -eq 0 ]
}

@test "Claude target creates no Codex role directory" {
  run run_fixture_installer --target claude
  [ "$status" -eq 0 ]
  [ ! -e "$FIXTURE_HOME/.codex/agents" ]
}

@test "both target installs each tracked role exactly once" {
  run run_fixture_installer --target both
  [ "$status" -eq 0 ]
  [ "$(find "$FIXTURE_HOME/.codex/agents" -type f -name '*.toml' | wc -l | tr -d ' ')" -eq 4 ]

  run run_fixture_installer --target both
  [ "$status" -eq 0 ]
  [ "$(awk -F $'\t' 'index($2, "/.codex/agents/") && $2 ~ /\.toml$/ { if (!($2 in count)) unique++; count[$2]++ } END { for (path in count) if (count[path] != 1) exit 1; print unique }' \
      "$FIXTURE_HOME/.deepwind/install/state.tsv")" -eq 4 ]
}

@test "an unchanged managed role updates to a newer release digest" {
  run run_fixture_installer --target codex
  [ "$status" -eq 0 ]
  printf '\n# fixture release v2\n' \
    >> "$FIXTURE_RELEASE/codex/codex/agents/harness-planner.toml"
  refresh_codex_fixture_archive

  run run_fixture_installer --target codex
  [ "$status" -eq 0 ]
  grep -q 'fixture release v2' "$FIXTURE_HOME/.codex/agents/harness-planner.toml"
  expected=$(test_sha256 "$FIXTURE_RELEASE/codex/codex/agents/harness-planner.toml")
  actual=$(awk -F $'\t' -v path="$FIXTURE_HOME/.codex/agents/harness-planner.toml" \
    '$2 == path { print $1 }' "$FIXTURE_HOME/.deepwind/install/state.tsv")
  [ "$actual" = "$expected" ]
}

@test "a locally modified managed role is preserved without force" {
  run run_fixture_installer --target codex
  [ "$status" -eq 0 ]
  printf 'user-owned role\n' > "$FIXTURE_HOME/.codex/agents/security-auditor.toml"
  printf '\n# fixture release v2\n' \
    >> "$FIXTURE_RELEASE/codex/codex/agents/security-auditor.toml"
  refresh_codex_fixture_archive

  run run_fixture_installer --target codex
  [ "$status" -eq 0 ]
  [ "$(cat "$FIXTURE_HOME/.codex/agents/security-auditor.toml")" = "user-owned role" ]
}

@test "force replaces a locally modified managed role through the transaction backup path" {
  run run_fixture_installer --target codex
  [ "$status" -eq 0 ]
  printf 'user-owned role\n' > "$FIXTURE_HOME/.codex/agents/frontend-developer.toml"
  printf '\n# fixture release v2\n' \
    >> "$FIXTURE_RELEASE/codex/codex/agents/frontend-developer.toml"
  refresh_codex_fixture_archive

  run run_fixture_installer --target codex --force
  [ "$status" -eq 0 ]
  grep -q 'fixture release v2' "$FIXTURE_HOME/.codex/agents/frontend-developer.toml"
}

@test "an untracked Codex role is rejected before destination mutation" {
  printf 'name = "unexpected"\n' \
    > "$FIXTURE_RELEASE/codex/codex/agents/unexpected.toml"
  refresh_codex_fixture_archive

  run run_fixture_installer --target codex
  [ "$status" -eq 2 ]
  [[ "$output" == *"untracked Codex role"* ]]
  [ ! -e "$FIXTURE_HOME/.codex" ]
}
