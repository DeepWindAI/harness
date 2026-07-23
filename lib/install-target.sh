# shellcheck shell=bash
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
      printf '%s/plugins/deepwind-harness/%s\n' "$CODEX_DIR" "${member#plugins/deepwind-harness/}"
      ;;
    codex:codex/agents/*)
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
        if destination=$(map_destination "$plan_target_name" "$member"); then
          :
        else
          map_status=$?
          [ "$map_status" -eq 3 ] && continue
          die "archive member has no allowlisted destination: $plan_target_name:$member"
        fi
        assert_contained_path "$destination"
        new_digest=$(sha256_file "$source_path")
        action=install
        old_digest=
        if [ -e "$destination" ]; then
          [ -f "$destination" ] && [ ! -L "$destination" ] \
            || die "managed destination is not a regular file: $destination"
          current_digest=$(sha256_file "$destination")
          if [ "$current_digest" = "$new_digest" ]; then
            action=unchanged
          elif old_digest=$(previous_digest "$destination" 2>/dev/null) \
            && [ "$current_digest" = "$old_digest" ]; then
            action=replace
          elif [ "$FORCE" -eq 1 ]; then
            action=replace
          else
            action=preserve
          fi
        fi
        printf '%s\t%s\t%s\t%s\t%s\n' \
          "$plan_target_name" "$source_path" "$destination" "$new_digest" "$action" >> "$PLAN_FILE"
      done
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
  return "$drift"
}
