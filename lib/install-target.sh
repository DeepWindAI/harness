# shellcheck shell=bash disable=SC2015
# Convert verified archive members into an allowlisted destination plan.

map_destination() {
  map_target=$1
  member=$2
  case "$map_target:$member" in
    claude:agents/*)
      printf '%s/%s\n' "$CLAUDE_DIR" "$member"
      ;;
    claude:skills/*)
      printf '%s/%s\n' "$CLAUDE_DIR" "$member"
      ;;
    claude:frameworks/*)
      printf '%s/%s\n' "$FRAMEWORKS_DIR" "${member#frameworks/}"
      ;;
    claude:README.md|claude:CLAUDE.md.starter)
      printf '%s/%s\n' "$FRAMEWORKS_DIR" "$member"
      ;;
    claude:payload/hooks/*)
      [ "$SKIP_HOOKS" -eq 0 ] || return 3
      printf '%s/hooks/%s\n' "$CLAUDE_DIR" "${member#payload/hooks/}"
      ;;
    claude:payload/bin/deepwind)
      printf '%s/deepwind\n' "$BIN_DIR"
      ;;
    claude:payload/mcp/*|claude:LICENSE|claude:VERSION)
      printf '%s/share/claude/%s\n' "$INSTALL_DIR" "$member"
      ;;
    codex:plugins/deepwind-harness/*)
      printf '%s/plugins/deepwind-harness/%s\n' "$CODEX_MARKETPLACE_DIR" "${member#plugins/deepwind-harness/}"
      ;;
    codex:.agents/plugins/marketplace.json)
      printf '%s/.agents/plugins/marketplace.json\n' "$CODEX_MARKETPLACE_DIR"
      ;;
    codex:codex/agents/frontend-developer.toml|\
    codex:codex/agents/harness-coordinator.toml|\
    codex:codex/agents/harness-planner.toml|\
    codex:codex/agents/security-auditor.toml)
      printf '%s/agents/%s\n' "$CODEX_DIR" "${member#codex/agents/}"
      ;;
    codex:LICENSE|codex:VERSION)
      printf '%s/share/codex/%s\n' "$INSTALL_DIR" "$member"
      ;;
    *)
      return 2
      ;;
  esac
}

codex_role_is_tracked() {
  case "$1" in
    frontend-developer.toml|\
    harness-coordinator.toml|\
    harness-planner.toml|\
    security-auditor.toml) return 0 ;;
    *) return 1 ;;
  esac
}

plan_managed_file() {
  managed_target=$1
  managed_source=$2
  managed_destination=$3
  managed_state_path=$4
  managed_force=$5
  assert_contained_path "$managed_destination"
  new_digest=$(sha256_file "$managed_source")
  action=install
  old_digest=
  if [ -e "$managed_destination" ]; then
    [ -f "$managed_destination" ] && [ ! -L "$managed_destination" ] \
      || die "managed destination is not a regular file: $managed_destination"
    current_digest=$(sha256_file "$managed_destination")
    if [ "$current_digest" = "$new_digest" ]; then
      action=unchanged
    elif [ -f "$managed_state_path" ] \
      && old_digest=$(awk -F '	' -v wanted="$managed_destination" \
        '$2 == wanted { print $1; found=1; exit } END { if (!found) exit 1 }' \
        "$managed_state_path") \
      && [ "$current_digest" = "$old_digest" ]; then
      action=replace
    elif [ "$managed_force" -eq 1 ]; then
      action=force-replace
    else
      action=preserve
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$managed_target" "$managed_source" "$managed_destination" "$new_digest" "$action" >> "$PLAN_FILE"
}

# Plan the complete, release-tracked Codex role pack. Mutation remains owned by
# apply_transaction so roles share the installer's journal, backup, and state.
install_codex_roles() {
  role_source_dir=$1
  role_destination_dir=$2
  role_state_path=$3
  role_force=$4
  case "$role_force" in 0|1) ;; *) die "invalid Codex role force mode" ;; esac

  while IFS= read -r role_file; do
    role_source="$role_source_dir/$role_file"
    [ -f "$role_source" ] && [ ! -L "$role_source" ] \
      || die "tracked Codex role is missing or unsafe: $role_file"
    plan_managed_file \
      codex \
      "$role_source" \
      "$role_destination_dir/$role_file" \
      "$role_state_path" \
      "$role_force"
  done <<'EOF'
frontend-developer.toml
harness-coordinator.toml
harness-planner.toml
security-auditor.toml
EOF
}

extract_and_plan_target() {
  plan_target_name=$1
  plan_archive=$2
  extract_root="$WORK_DIR/extracted-$plan_target_name"
  mkdir "$extract_root"
  tar -xzf "$plan_archive" -C "$extract_root" || die "cannot extract $plan_target_name archive"

  jq -r --arg target "$plan_target_name" \
    '.archives[] | select(.target == $target) | .files[]' "$MANIFEST_FILE" \
    | while IFS= read -r member; do
        case "$member" in */) continue ;; esac
        source_path="$extract_root/$member"
        [ -f "$source_path" ] && [ ! -L "$source_path" ] \
          || die "archive member is not a regular file: $member"
        if [ "$plan_target_name" = codex ]; then
          case "$member" in
            codex/agents/*)
              role_file=${member#codex/agents/}
              case "$role_file" in */*) die "untracked Codex role: $member" ;; esac
              codex_role_is_tracked "$role_file" \
                || die "untracked Codex role: $member"
              continue
              ;;
          esac
        fi
        if destination=$(map_destination "$plan_target_name" "$member"); then
          :
        else
          map_status=$?
          [ "$map_status" -eq 3 ] && continue
          die "archive member has no allowlisted destination: $plan_target_name:$member"
        fi
        plan_managed_file \
          "$plan_target_name" "$source_path" "$destination" "$STATE_FILE" "$FORCE"
      done
  if [ "$plan_target_name" = codex ]; then
    install_codex_roles \
      "$extract_root/codex/agents" "$CODEX_DIR/agents" "$STATE_FILE" "$FORCE"
  fi
}

plan_release_install() {
  PLAN_FILE="$WORK_DIR/install-plan.tsv"
  : > "$PLAN_FILE"
  if target_selected claude; then extract_and_plan_target claude "$CLAUDE_ARCHIVE"; fi
  if target_selected codex; then extract_and_plan_target codex "$CODEX_ARCHIVE"; fi
  [ -s "$PLAN_FILE" ] || die "selected release contains no installable files"
  duplicate_destination=$(awk -F '	' '{ count[$3]++ } END { for (path in count) if (count[path] > 1) { print path; exit } }' \
    "$PLAN_FILE")
  [ -z "$duplicate_destination" ] \
    || die "multiple archive members map to one destination: $duplicate_destination"
}

print_plan() {
  while IFS='	' read -r plan_target_name source_path destination new_digest action; do
    printf '%-9s %-8s %s\n' "$plan_target_name" "$action" "$destination"
  done < "$PLAN_FILE"
  return 0
}

check_plan() {
  drift=0
  while IFS='	' read -r plan_target_name source_path destination new_digest action; do
    case "$action" in
      unchanged) ;;
      *) drift=1; printf 'drift: %s (%s)\n' "$destination" "$action" ;;
    esac
  done < "$PLAN_FILE"
  check_recovery_backups || drift=1
  if target_selected codex; then
    print_codex_plugin_status || drift=1
  fi
  return "$drift"
}
