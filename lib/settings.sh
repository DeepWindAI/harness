# shellcheck shell=bash disable=SC2015,SC2034
# Register the merge-guard PreToolUse[Bash] hook in ~/.claude/settings.json.
#
# Claude Code only fires hooks that are DECLARED in settings.json — copying the hook
# file into ~/.claude/hooks/ is not enough. This unit adds one idempotent PreToolUse
# entry pointing at the installed pre-bash-merge-guard.sh so the gate actually enforces.
#
# Safety model: this is the ONLY place the installer edits a user-owned file it does not
# fully own. It therefore:
#   - only runs when the hook is actually part of this install (SKIP_HOOKS=0, claude
#     target, and the hook file is in the plan),
#   - is a no-op when the command is already registered (preserves the user's formatting),
#   - never touches a symlinked / non-regular settings.json or one that is not valid JSON
#     (warns and skips — the user registers manually),
#   - performs the write through install_one_file, so the existing journal backs up the
#     prior settings.json and rollback restores it byte-for-byte on any later failure.
# settings.json is deliberately NOT added to the managed state list: the installer owns
# only this one hook fragment, not the whole file, so it must not drift-track it.

merge_gate_settings_file() { printf '%s/settings.json\n' "$CLAUDE_DIR"; }
merge_gate_hook_command() { printf '%s/hooks/pre-bash-merge-guard.sh\n' "$CLAUDE_DIR"; }

# jq predicate: is $cmd already present as a PreToolUse command hook?
merge_gate_hook_registered() {
  mgr_file=$1
  mgr_cmd=$2
  [ -f "$mgr_file" ] && [ ! -L "$mgr_file" ] || return 1
  jq -e --arg cmd "$mgr_cmd" \
    '[ (.hooks.PreToolUse // [])[]? | (.hooks // [])[]? | .command? ] | any(. == $cmd)' \
    "$mgr_file" >/dev/null 2>&1
}

# Is the hook file part of THIS install plan (so registering it makes sense)?
merge_gate_hook_in_plan() {
  [ -n "${PLAN_FILE:-}" ] && [ -f "$PLAN_FILE" ] || return 1
  awk -F '\t' -v want="$CLAUDE_DIR/hooks/pre-bash-merge-guard.sh" \
    '$3 == want { found = 1 } END { exit !found }' "$PLAN_FILE"
}

# Registration disposition for reporting (dry-run/check) and gating (install):
#   0 = a clean registration WOULD occur (hook in plan, not yet registered, file mergeable)
#   1 = nothing to do (skip-hooks, non-claude, hook not in plan, or already registered)
#   2 = hook is in plan + unregistered, but settings.json is unmergeable → MANUAL needed
merge_gate_registration_status() {
  [ "${SKIP_HOOKS:-0}" -eq 0 ] || return 1
  target_selected claude || return 1
  merge_gate_hook_in_plan || return 1
  mgr_settings=$(merge_gate_settings_file)
  mgr_cmd=$(merge_gate_hook_command)
  merge_gate_hook_registered "$mgr_settings" "$mgr_cmd" && return 1
  if [ -e "$mgr_settings" ]; then
    if [ -L "$mgr_settings" ] || [ ! -f "$mgr_settings" ]; then return 2; fi
    jq -e . "$mgr_settings" >/dev/null 2>&1 || return 2
  fi
  return 0
}

# Print a plan line describing the settings.json disposition (dry-run parity with print_plan).
print_merge_gate_plan() {
  merge_gate_registration_status
  case "$?" in
    0) printf '%-9s %-8s %s\n' claude register "$(merge_gate_settings_file) (PreToolUse[Bash] merge-guard)" ;;
    2) printf '%-9s %-8s %s\n' claude manual "$(merge_gate_settings_file) (unparseable — register merge-guard by hand)" ;;
    *) : ;;
  esac
  return 0
}

# Report settings-registration drift for check_plan. Returns 1 (drift) if action needed.
check_merge_gate_registration() {
  merge_gate_registration_status
  case "$?" in
    0) printf 'drift: %s (register merge-guard PreToolUse[Bash] hook)\n' "$(merge_gate_settings_file)"; return 1 ;;
    2) printf 'drift: %s (unparseable settings.json — register merge-guard by hand)\n' "$(merge_gate_settings_file)"; return 1 ;;
    *) return 0 ;;
  esac
}

# Perform the registration inside the journaled transaction (install mode only).
# Must be called from apply_transaction after JOURNAL_FILE/BACKUP_DIR/MUTATION_COUNT
# are initialised and before TRANSACTION_COMMITTED, so a later failure rolls it back.
register_merge_gate_hook() {
  merge_gate_registration_status
  reg_status=$?
  if [ "$reg_status" -eq 2 ]; then
    warn "settings.json is not mergeable JSON; skipping merge-guard hook registration (register it by hand)"
    return 0
  fi
  [ "$reg_status" -eq 0 ] || return 0

  reg_settings=$(merge_gate_settings_file)
  reg_cmd=$(merge_gate_hook_command)
  if [ -e "$reg_settings" ]; then
    reg_current=$(cat "$reg_settings")
  else
    reg_current='{}'
  fi

  reg_merged="$WORK_DIR/settings.merged.json"
  if ! printf '%s' "$reg_current" | jq --arg cmd "$reg_cmd" '
      . as $root
      | ($root.hooks // {}) as $h
      | ($h.PreToolUse // []) as $pre
      | ( [ ($pre[]?) | (.hooks // [])[]? | .command? ] | any(. == $cmd) ) as $present
      | if $present then $root
        else $root
          | .hooks = ($h | .PreToolUse = ($pre + [ {matcher: "Bash", hooks: [ {type: "command", command: $cmd} ]} ]))
        end
    ' > "$reg_merged" 2>/dev/null; then
    warn "could not merge merge-guard hook into settings.json; skipping registration"
    return 0
  fi

  # Sanity: the merged file must be valid JSON AND now contain our command.
  merge_gate_hook_registered "$reg_merged" "$reg_cmd" \
    || { warn "merge-guard registration sanity check failed; skipping"; return 0; }

  install_one_file "$reg_merged" "$reg_settings" 0
  info "registered merge-guard PreToolUse[Bash] hook in $reg_settings"
}
