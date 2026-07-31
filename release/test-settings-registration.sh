#!/usr/bin/env bash
# Runtime contract for lib/settings.sh — the merge-guard PreToolUse[Bash] registration
# in ~/.claude/settings.json. Exercises the REAL install_one_file transaction primitive
# against a throwaway HOME (no signing, no network). Covers: fresh register, idempotent
# re-run, preservation of unrelated keys/hooks, safe skip of unparseable/symlinked files,
# skip-hooks + hook-not-in-plan suppression, check/dry-run reporting, and rollback.
#
# SC2015: the `A && ok || no` assertion idiom is intentional (ok/no both just tally+print,
#   never fail, so the "C may run when A is true" caveat does not apply here).
# SC2034: TARGET/SKIP_HOOKS/MUTATION_COUNT are consumed by the sourced lib functions.
# shellcheck disable=SC2015,SC2034
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); printf '  [ok]   %s\n' "$1"; }
no() { FAIL=$((FAIL + 1)); printf '  [FAIL] %s\n' "$1"; }

setup() {
  HOME=$(mktemp -d "${TMPDIR:-/tmp}/dw-settings-test.XXXXXX")
  export HOME
  # shellcheck source=/dev/null
  . "$ROOT/lib/state.sh"
  # shellcheck source=/dev/null
  . "$ROOT/lib/args.sh"
  # shellcheck source=/dev/null
  . "$ROOT/lib/manifest.sh"
  # shellcheck source=/dev/null
  . "$ROOT/lib/install-target.sh"
  # shellcheck source=/dev/null
  . "$ROOT/lib/transaction.sh"
  # shellcheck source=/dev/null
  . "$ROOT/lib/settings.sh"
  configure_paths
  mkdir -p "$CLAUDE_DIR/hooks" "$BIN_DIR" "$INSTALL_DIR"
  TARGET=claude
  SKIP_HOOKS=0
  WORK_DIR=$(mktemp -d "$HOME/work.XXXXXX")
  JOURNAL_FILE="$WORK_DIR/journal.tsv"
  : > "$JOURNAL_FILE"
  BACKUP_DIR="$WORK_DIR/backups"
  mkdir -p "$BACKUP_DIR"
  MUTATION_COUNT=0
  PLAN_FILE="$WORK_DIR/plan.tsv"
  printf 'claude\t/src\t%s/hooks/pre-bash-merge-guard.sh\tdigest\tinstall\n' \
    "$CLAUDE_DIR" > "$PLAN_FILE"
  SETTINGS="$CLAUDE_DIR/settings.json"
  CMD="$CLAUDE_DIR/hooks/pre-bash-merge-guard.sh"
}

cmd_count() {
  jq --arg cmd "$CMD" \
    '[ (.hooks.PreToolUse // [])[]? | (.hooks // [])[]? | .command? ] | map(select(. == $cmd)) | length' \
    "$SETTINGS" 2>/dev/null
}

echo "1. fresh install (no settings.json) registers exactly one hook"
setup
register_merge_gate_hook >/dev/null 2>&1
{ [ -f "$SETTINGS" ] && [ "$(cmd_count)" = "1" ]; } && ok "created with one merge-guard entry" || no "did not register on fresh"
jq -e '.hooks.PreToolUse[0].matcher == "Bash"' "$SETTINGS" >/dev/null 2>&1 && ok "matcher is Bash" || no "matcher wrong"

echo "2. re-run is idempotent (no duplicate, byte-unchanged)"
before=$(sha256_file "$SETTINGS")
register_merge_gate_hook >/dev/null 2>&1
[ "$(cmd_count)" = "1" ] && ok "still exactly one entry" || no "duplicate created"
[ "$(sha256_file "$SETTINGS")" = "$before" ] && ok "file byte-identical" || no "file rewritten needlessly"

echo "3. existing settings keys/hooks preserved"
setup
printf '%s\n' '{"model":"opus","hooks":{"PostToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"x"}]}]}}' > "$SETTINGS"
register_merge_gate_hook >/dev/null 2>&1
jq -e '.model == "opus"' "$SETTINGS" >/dev/null 2>&1 && ok ".model preserved" || no ".model lost"
jq -e '.hooks.PostToolUse[0].matcher == "Edit"' "$SETTINGS" >/dev/null 2>&1 && ok "PostToolUse preserved" || no "PostToolUse lost"
[ "$(cmd_count)" = "1" ] && ok "merge-guard appended" || no "merge-guard not added"

echo "4. unparseable settings.json is not clobbered"
setup
printf '%s' 'not json {{{' > "$SETTINGS"
rc=0; merge_gate_registration_status || rc=$?
[ "$rc" = "2" ] && ok "status=2 (manual)" || no "wrong status $rc for unparseable"
register_merge_gate_hook >/dev/null 2>&1
[ "$(cat "$SETTINGS")" = 'not json {{{' ] && ok "left untouched" || no "clobbered a bad settings.json"

echo "5. symlinked settings.json is skipped"
setup
printf '{}' > "$HOME/real-settings.json"
ln -s "$HOME/real-settings.json" "$SETTINGS"
rc=0; merge_gate_registration_status || rc=$?
[ "$rc" = "2" ] && ok "status=2 for symlink" || no "wrong status $rc for symlink"
register_merge_gate_hook >/dev/null 2>&1
[ -L "$SETTINGS" ] && ok "symlink not replaced" || no "symlink clobbered"

echo "6. skip-hooks and hook-not-in-plan suppress registration"
setup
SKIP_HOOKS=1
rc=0; merge_gate_registration_status || rc=$?
[ "$rc" = "1" ] && ok "skip-hooks -> no-op" || no "skip-hooks not honored (status $rc)"
setup
: > "$PLAN_FILE"
rc=0; merge_gate_registration_status || rc=$?
[ "$rc" = "1" ] && ok "hook-not-in-plan -> no-op" || no "registered without hook in plan (status $rc)"

echo "7. check/dry-run reporting"
setup
rc=0; check_merge_gate_registration >/dev/null 2>&1 || rc=$?
[ "$rc" = "1" ] && ok "check reports drift when unregistered" || no "check missed drift"
print_merge_gate_plan 2>/dev/null | grep -q register && ok "dry-run prints a register line" || no "dry-run missing register line"
register_merge_gate_hook >/dev/null 2>&1
rc=0; check_merge_gate_registration >/dev/null 2>&1 || rc=$?
[ "$rc" = "0" ] && ok "check clean after registration" || no "check still drifts"

echo "8. rollback restores the prior settings.json"
setup
printf '%s\n' '{"model":"sonnet"}' > "$SETTINGS"
prior=$(sha256_file "$SETTINGS")
register_merge_gate_hook >/dev/null 2>&1
[ "$(cmd_count)" = "1" ] && ok "registered (pre-rollback)" || no "did not register"
rollback_transaction >/dev/null 2>&1
[ "$(sha256_file "$SETTINGS")" = "$prior" ] && ok "rollback restored prior settings.json" || no "rollback did not restore"

printf '\nRESULT: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
