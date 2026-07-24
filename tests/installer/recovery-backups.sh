#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=tests/installer/helpers.bash
. "$ROOT/helpers.bash"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mode_of() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

make_fixture_release
trap remove_fixture_release EXIT HUP INT TERM

run_fixture_installer --target codex >/dev/null
[ ! -e "$FIXTURE_HOME/.deepwind/install/recovery.tsv" ] \
  || fail 'fresh install created a recovery record without a forced local replacement'
printf '\n# ordinary managed upgrade\n' \
  >> "$FIXTURE_RELEASE/codex/codex/agents/harness-planner.toml"
refresh_codex_fixture_archive
run_fixture_installer --target codex >/dev/null
[ ! -e "$FIXTURE_HOME/.deepwind/install/recovery.tsv" ] \
  || fail 'ordinary managed upgrade created a durable recovery backup'

mkdir -p "$FIXTURE_HOME/.mcp-auth"
printf 'oauth-secret-must-not-be-backed-up\n' > "$FIXTURE_HOME/.mcp-auth/tokens.json"
printf 'codex-auth-secret-must-not-be-backed-up\n' > "$FIXTURE_HOME/.codex/auth.json"
oauth_digest=$(test_sha256 "$FIXTURE_HOME/.mcp-auth/tokens.json")
auth_digest=$(test_sha256 "$FIXTURE_HOME/.codex/auth.json")

managed_role="$FIXTURE_HOME/.codex/agents/frontend-developer.toml"
printf 'first user-owned role\n' > "$managed_role"
run_fixture_installer --target codex --force >/dev/null

recovery_state="$FIXTURE_HOME/.deepwind/install/recovery.tsv"
[ -f "$recovery_state" ] || fail 'successful force did not create recovery state'
[ "$(mode_of "$recovery_state")" = 600 ] || fail 'recovery state is not private'
[ "$(awk 'END { print NR }' "$recovery_state")" -eq 1 ] \
  || fail 'first force did not record exactly one recovery backup'

IFS=$'\t' read -r first_created first_digest first_backup first_destination \
  < "$recovery_state"
case "${first_created##*/}" in
  [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z-[0-9]*)
    ;;
  *) fail 'recovery run is not timestamped' ;;
esac
[ "$first_destination" = "$managed_role" ] \
  || fail 'recovery state points at the wrong managed destination'
[ -f "$first_backup" ] || fail 'retained backup is missing'
[ "$(cat "$first_backup")" = 'first user-owned role' ] \
  || fail 'retained backup does not contain the forced local version'
[ "$(test_sha256 "$first_backup")" = "$first_digest" ] \
  || fail 'retained backup digest does not match recovery state'
[ "$(mode_of "$first_backup")" = 600 ] || fail 'retained backup is not private'
[ "$(mode_of "${first_backup%/*}")" = 700 ] \
  || fail 'timestamped recovery directory is not private'

[ "$(test_sha256 "$FIXTURE_HOME/.mcp-auth/tokens.json")" = "$oauth_digest" ] \
  || fail 'OAuth cache changed during forced replacement'
[ "$(test_sha256 "$FIXTURE_HOME/.codex/auth.json")" = "$auth_digest" ] \
  || fail 'Codex auth state changed during forced replacement'
if rg -q \
  'oauth-secret-must-not-be-backed-up|codex-auth-secret-must-not-be-backed-up|[.]mcp-auth|auth[.]json' \
  "$FIXTURE_HOME/.deepwind/install/recovery" "$recovery_state"; then
  fail 'recovery storage captured OAuth/token data or paths'
fi

printf 'second user-owned role\n' > "$managed_role"
run_fixture_installer --target codex --force >/dev/null
[ "$(awk 'END { print NR }' "$recovery_state")" -eq 2 ] \
  || fail 'a later force pruned or replaced prior recovery state'
[ -f "$first_backup" ] || fail 'a later force pruned the first backup'
second_backup=$(awk -F '\t' 'END { print $3 }' "$recovery_state")
[ "$(cat "$second_backup")" = 'second user-owned role' ] \
  || fail 'second forced local version was not retained'

printf 'third user-owned role\n' > "$managed_role"
state_before_check=$(test_sha256 "$recovery_state")
backup_count_before_check=$(find "$FIXTURE_HOME/.deepwind/install/recovery" -type f | wc -l | tr -d '[:space:]')
if run_fixture_installer --target codex --check --force \
  > "$FIXTURE_ROOT/check.out" 2>&1; then
  fail 'check accepted a forced local replacement as unchanged'
fi
[ "$(test_sha256 "$recovery_state")" = "$state_before_check" ] \
  || fail 'check mode mutated recovery state'
[ "$(find "$FIXTURE_HOME/.deepwind/install/recovery" -type f | wc -l | tr -d '[:space:]')" \
    = "$backup_count_before_check" ] || fail 'check mode wrote a recovery backup'

if env \
  HOME="$FIXTURE_HOME" \
  TMPDIR="$FIXTURE_HOME/tmp" \
  PATH="$FIXTURE_ROOT/bin:$PATH" \
  DEEPWIND_INSTALL_TESTING=1 \
  DEEPWIND_TEST_INTERRUPT_AFTER_MUTATIONS=1 \
  DEEPWIND_RELEASE_DIR="$FIXTURE_RELEASE" \
  bash "$FIXTURE_INSTALLER" --version 1.2.3 --target codex --force \
  > "$FIXTURE_ROOT/interrupted.out" 2>&1; then
  fail 'interrupted forced replacement succeeded'
fi
[ "$(cat "$managed_role")" = 'third user-owned role' ] \
  || fail 'interrupted force did not restore the local version'
[ "$(test_sha256 "$recovery_state")" = "$state_before_check" ] \
  || fail 'interrupted force changed durable recovery state'

doctor_output=$(
  HOME="$FIXTURE_HOME"
  # shellcheck source=lib/state.sh
  . "$TEST_ROOT/lib/state.sh"
  # shellcheck source=lib/codex-mcp.sh
  . "$TEST_ROOT/lib/codex-mcp.sh"
  # shellcheck source=lib/doctor.sh
  . "$TEST_ROOT/lib/doctor.sh"
  configure_paths
  doctor claude
)
printf '%s\n' "$doctor_output" | rg -q \
  '"component":"recovery","status":"available","count":2' \
  || fail 'doctor did not report the retained recovery count'
if printf '%s\n' "$doctor_output" | rg -q \
  'oauth|token|auth[.]json|[.]mcp-auth'; then
  fail 'doctor exposed sensitive or managed recovery paths'
fi

printf 'tampered\n' >> "$first_backup"
if run_fixture_installer --target codex --check --force \
  > "$FIXTURE_ROOT/tampered-check.out" 2>&1; then
  fail 'check accepted a tampered retained backup'
fi
rg -q 'recovery: attention-required' "$FIXTURE_ROOT/tampered-check.out" \
  || fail 'check did not report invalid recovery state'
if rg -q \
  'oauth-secret-must-not-be-backed-up|codex-auth-secret-must-not-be-backed-up|auth[.]json|[.]mcp-auth' \
  "$FIXTURE_ROOT/tampered-check.out" \
  || grep -Fq "$first_backup" "$FIXTURE_ROOT/tampered-check.out"; then
  fail 'check exposed sensitive or managed recovery paths'
fi

managed_before_invalid_install=$(test_sha256 "$managed_role")
state_before_invalid_install=$(test_sha256 "$FIXTURE_HOME/.deepwind/install/state.tsv")
if run_fixture_installer --target codex --force \
  > "$FIXTURE_ROOT/invalid-install.out" 2>&1; then
  fail 'installer accepted invalid retained recovery state'
fi
[ "$(test_sha256 "$managed_role")" = "$managed_before_invalid_install" ] \
  || fail 'invalid recovery state was detected after destination mutation'
[ "$(test_sha256 "$FIXTURE_HOME/.deepwind/install/state.tsv")" = "$state_before_invalid_install" ] \
  || fail 'invalid recovery state changed managed installer state'

printf 'PASS: forced replacement recovery backup contract\n'
