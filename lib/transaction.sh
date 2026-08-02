# shellcheck shell=bash disable=SC2015,SC2034
# Journaled, atomic destination mutation and rollback.

ensure_parent_directories() {
  parent=${1%/*}
  missing=
  cursor=$parent
  while [ "$cursor" != "$HOME" ] && [ ! -d "$cursor" ]; do
    missing="$cursor
$missing"
    cursor=${cursor%/*}
  done
  [ -d "$cursor" ] && [ ! -L "$cursor" ] || die "unsafe destination parent: $cursor"
  printf '%s' "$missing" | while IFS= read -r directory; do
    [ -n "$directory" ] || continue
    mkdir "$directory" || return 1
    printf 'D\t%s\n' "$directory" >> "$JOURNAL_FILE"
  done
}

rollback_transaction() {
  [ -n "${JOURNAL_FILE:-}" ] && [ -f "$JOURNAL_FILE" ] || return 0
  reverse_journal="$WORK_DIR/journal.reverse"
  awk '{ lines[NR]=$0 } END { for (i=NR; i>=1; i--) print lines[i] }' \
    "$JOURNAL_FILE" > "$reverse_journal"
  ROLLBACK_INCOMPLETE=0
  while IFS='	' read -r kind destination backup had_existing; do
    case "$kind" in
      F)
        if [ "$had_existing" = 1 ]; then
          if rm -f "$destination" && mv "$backup" "$destination"; then
            :
          else
            ROLLBACK_INCOMPLETE=1
          fi
        else
          rm -f "$destination" || ROLLBACK_INCOMPLETE=1
        fi
        ;;
      D)
        rmdir "$destination" 2>/dev/null || {
          [ ! -d "$destination" ] || ROLLBACK_INCOMPLETE=1
        }
        ;;
      T)
        rm -f "$destination" || ROLLBACK_INCOMPLETE=1
        ;;
      R)
        # Retired plugin aliases have no current destination. Restore one only
        # when a failed transaction did not create anything in its place.
        if [ ! -e "$destination" ] && [ ! -L "$destination" ] \
          && mv "$backup" "$destination"; then
          :
        else
          ROLLBACK_INCOMPLETE=1
        fi
        ;;
    esac
  done < "$reverse_journal"
  if [ "$ROLLBACK_INCOMPLETE" -ne 0 ]; then
    warn "rollback needs manual repair; recovery journal retained at $WORK_DIR"
    RETAIN_WORK_DIR=1
  fi
  return 0
}

retired_codex_plugin_skill_path() {
  case "$1" in
    "$CODEX_MARKETPLACE_DIR"/plugins/deepwind-harness/skills/harness-prep|\
    "$CODEX_MARKETPLACE_DIR"/plugins/deepwind-harness/skills/harness-planner|\
    "$CODEX_MARKETPLACE_DIR"/plugins/deepwind-harness/skills/harness-coordinator|\
    "$CODEX_MARKETPLACE_DIR"/plugins/deepwind-harness/skills/harness-discipline)
      return 0
      ;;
    *) return 1 ;;
  esac
}

retired_codex_plugin_skill_file() {
  retired_codex_plugin_skill_path "${1%/SKILL.md}"
}

retire_codex_plugin_skill_aliases() {
  # Releases before the formal catalog placed unprefixed aliases inside the
  # plugin. Retire only those exact installer-owned directories, never a
  # wildcard or a user-provided skill, so upgrades expose every skill once.
  for retired_name in harness-prep harness-planner harness-coordinator harness-discipline; do
    retired_path="$CODEX_MARKETPLACE_DIR/plugins/deepwind-harness/skills/$retired_name"
    retired_codex_plugin_skill_path "$retired_path" \
      || die "unsafe retired Codex plugin skill path"
    [ ! -L "$retired_path" ] || die "symlink in retired Codex plugin skill path: $retired_path"
    [ ! -e "$retired_path" ] || {
      [ -d "$retired_path" ] || die "retired Codex plugin skill is not a directory: $retired_path"
      retired_backup="$BACKUP_DIR/retired-codex-skill-$retired_name"
      mv "$retired_path" "$retired_backup" \
        || die "cannot retire obsolete Codex plugin skill: $retired_name"
      printf 'R\t%s\t%s\t1\n' "$retired_path" "$retired_backup" >> "$JOURNAL_FILE"
    }
  done
}

install_one_file() {
  source_path=$1
  destination=$2
  retain_forced_backup=${3:-0}
  backup_path=
  had_existing=0
  assert_contained_path "$destination"
  ensure_parent_directories "$destination" || die "cannot create destination directory"
  if [ -e "$destination" ]; then
    had_existing=1
    backup_path="$BACKUP_DIR/backup-$MUTATION_COUNT"
    cp -p "$destination" "$backup_path" || die "cannot back up managed file"
    if [ "$retain_forced_backup" -eq 1 ]; then
      recovery_destination_allowed "$destination" \
        || die "forced replacement is not an allowlisted recovery destination"
      backup_digest=$(sha256_file "$backup_path")
      printf '%s\t%s\t%s\n' "$backup_digest" "$backup_path" "$destination" \
        >> "$PENDING_FORCE_BACKUPS"
    fi
  fi
  printf 'F\t%s\t%s\t%s\n' "$destination" "$backup_path" "$had_existing" >> "$JOURNAL_FILE"
  adjacent="$destination.deepwind-new.$$"
  printf 'T\t%s\t\t0\n' "$adjacent" >> "$JOURNAL_FILE"
  cp "$source_path" "$adjacent" || die "cannot stage destination file"
  case "$destination" in
    "$BIN_DIR"/*|"$CLAUDE_DIR/hooks/"*) chmod 755 "$adjacent" ;;
    "$RECOVERY_ROOT"/*|"$RECOVERY_STATE_FILE") chmod 600 "$adjacent" ;;
    *) chmod 644 "$adjacent" ;;
  esac
  mv -f "$adjacent" "$destination" || die "cannot atomically replace destination"
  MUTATION_COUNT=$((MUTATION_COUNT + 1))
  if [ "${DEEPWIND_INSTALL_TESTING:-0}" = 1 ] \
    && [ "${DEEPWIND_TEST_INTERRUPT_AFTER_MUTATIONS:-}" = "$MUTATION_COUNT" ]; then
    kill -TERM "$$"
  fi
}

persist_forced_backups() {
  [ -s "$PENDING_FORCE_BACKUPS" ] || return 0
  recovery_stamp=$(date -u +%Y%m%dT%H%M%SZ)
  recovery_run="$RECOVERY_ROOT/$recovery_stamp-$$"
  assert_contained_path "$recovery_run"
  [ ! -e "$recovery_run" ] || die "recovery run path already exists"

  recovery_next="$WORK_DIR/recovery.next"
  if [ -f "$RECOVERY_STATE_FILE" ]; then
    cp "$RECOVERY_STATE_FILE" "$recovery_next" \
      || die "cannot stage recovery state"
  else
    : > "$recovery_next"
  fi

  recovery_index=0
  while IFS='	' read -r recovery_digest rollback_backup recovery_destination; do
    recovery_index=$((recovery_index + 1))
    retained_backup="$recovery_run/backup-$recovery_index"
    install_one_file "$rollback_backup" "$retained_backup" 0
    [ "$(sha256_file "$retained_backup")" = "$recovery_digest" ] \
      || die "retained recovery backup digest mismatch"
    printf '%s\t%s\t%s\t%s\n' \
      "$recovery_run" "$recovery_digest" "$retained_backup" "$recovery_destination" \
      >> "$recovery_next"
  done < "$PENDING_FORCE_BACKUPS"

  install_one_file "$recovery_next" "$RECOVERY_STATE_FILE" 0
}

build_next_state() {
  next_state=$1
  : > "$next_state"
  if [ -f "$STATE_FILE" ]; then
    while IFS='	' read -r retained_digest retained_path; do
      retired_codex_plugin_skill_file "$retained_path" && continue
      if ! awk -F '	' -v wanted="$retained_path" \
        '$3 == wanted { found=1 } END { exit !found }' "$PLAN_FILE"; then
        printf '%s\t%s\n' "$retained_digest" "$retained_path" >> "$next_state"
      fi
    done < "$STATE_FILE"
  fi
  while IFS='	' read -r plan_target_name source_path destination new_digest action; do
    case "$action" in
      preserve)
        if old_digest=$(previous_digest "$destination" 2>/dev/null); then
          printf '%s\t%s\n' "$old_digest" "$destination" >> "$next_state"
        fi
        ;;
      *)
        printf '%s\t%s\n' "$new_digest" "$destination" >> "$next_state"
        ;;
    esac
  done < "$PLAN_FILE"
  LC_ALL=C sort -u "$next_state" -o "$next_state"
}

apply_transaction() {
  acquire_lock
  recovery_state_summary \
    || die "retained recovery state requires attention before installation"
  JOURNAL_FILE="$WORK_DIR/journal.tsv"
  BACKUP_DIR="$WORK_DIR/backups"
  mkdir "$BACKUP_DIR"
  : > "$JOURNAL_FILE"
  PENDING_FORCE_BACKUPS="$WORK_DIR/forced-backups.tsv"
  : > "$PENDING_FORCE_BACKUPS"
  MUTATION_COUNT=0
  last_target=

  if target_selected codex; then
    retire_codex_plugin_skill_aliases
  fi

  while IFS='	' read -r plan_target_name source_path destination new_digest action; do
    if [ "$plan_target_name" != "$last_target" ]; then
      last_target=$plan_target_name
      if [ "${DEEPWIND_INSTALL_TESTING:-0}" = 1 ] \
        && [ "${DEEPWIND_TEST_FAIL_TARGET:-}" = "$plan_target_name" ]; then
        die "injected failure for $plan_target_name"
      fi
    fi
    case "$action" in
      install|replace) install_one_file "$source_path" "$destination" 0 ;;
      force-replace) install_one_file "$source_path" "$destination" 1 ;;
      preserve) warn "preserving locally modified file: $destination" ;;
      unchanged) ;;
      *) die "invalid install action: $action" ;;
    esac
  done < "$PLAN_FILE"

  # Register the merge-guard hook in settings.json (journaled via install_one_file, so a
  # later failure rolls back the prior settings.json). No-op unless the hook is installed
  # and not already registered. Runs before the state write so it shares this transaction.
  register_merge_gate_hook

  next_state="$WORK_DIR/state.next"
  build_next_state "$next_state"
  install_one_file "$next_state" "$STATE_FILE" 0
  persist_forced_backups
  TRANSACTION_COMMITTED=1
  release_lock
}
