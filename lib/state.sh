# shellcheck shell=bash disable=SC2015,SC2034
# Environment, path-containment, lock, and state helpers.

die() {
  printf 'deepwind-init: %s\n' "$*" >&2
  exit 2
}

info() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

configure_paths() {
  CLAUDE_DIR="$HOME/.claude"
  CODEX_DIR="$HOME/.codex"
  AGENTS_DIR="$HOME/.agents"
  FRAMEWORKS_DIR="$HOME/deepwind-frameworks"
  INSTALL_DIR="$HOME/.deepwind/install"
  CODEX_MARKETPLACE_DIR="$INSTALL_DIR/share/codex-marketplace"
  BIN_DIR="$HOME/.deepwind/bin"
  LOCK_DIR="$HOME/.deepwind-install.lock"
  STATE_FILE="$INSTALL_DIR/state.tsv"
  RECOVERY_ROOT="$INSTALL_DIR/recovery"
  RECOVERY_STATE_FILE="$INSTALL_DIR/recovery.tsv"
}

assert_safe_home() {
  [ "$(id -u)" -ne 0 ] || die "refusing to run as root"
  [ -n "${HOME:-}" ] || die "HOME is unset"
  case "$HOME" in
    /*) ;;
    *) die "HOME must be an absolute path" ;;
  esac
  case "$HOME" in
    /|/root|*/../*|*/..|*/./*|*/.|*'
'*|*'	'*) die "unsafe HOME: $HOME" ;;
  esac
  [ -d "$HOME" ] || die "HOME is not a directory"
  [ ! -L "$HOME" ] || die "HOME must not be a symlink"
  home_real=$(realpath "$HOME") || die "cannot resolve HOME"
  [ "$home_real" = "${HOME%/}" ] || die "HOME is not canonical"
  if stat -f '%u' "$HOME" >/dev/null 2>&1; then
    home_owner=$(stat -f '%u' "$HOME")
  else
    home_owner=$(stat -c '%u' "$HOME")
  fi
  [ "$home_owner" = "$(id -u)" ] || die "HOME is not owned by the current user"
}

assert_contained_path() {
  candidate=$1
  case "$candidate" in
    "$HOME"/*) ;;
    *) die "path is outside HOME: $candidate" ;;
  esac
  case "$candidate" in *'/../'*|*'/..'|*'/./'*|*'/.'|*'
'*|*'	'*) die "unsafe destination path" ;; esac

  cursor=$candidate
  while [ "$cursor" != "$HOME" ]; do
    if [ -e "$cursor" ] || [ -L "$cursor" ]; then
      [ ! -L "$cursor" ] || die "symlink in managed path: $cursor"
    fi
    cursor=${cursor%/*}
    [ -n "$cursor" ] || die "cannot contain destination path"
  done
}

acquire_lock() {
  assert_contained_path "$LOCK_DIR"
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    die "another DeepWind install is active (lock: $LOCK_DIR)"
  fi
  LOCK_HELD=1
}

release_lock() {
  if [ "${LOCK_HELD:-0}" -eq 1 ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
    LOCK_HELD=0
  fi
  return 0
}

previous_digest() {
  state_path=$1
  [ -f "$STATE_FILE" ] || return 1
  awk -F '	' -v wanted="$state_path" '$2 == wanted { print $1; found=1; exit } END { if (!found) exit 1 }' "$STATE_FILE"
}

private_mode() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

recovery_destination_allowed() {
  recovery_destination=$1
  case "$recovery_destination" in
    "$CLAUDE_DIR"/agents/*|\
    "$CLAUDE_DIR"/skills/*|\
    "$CLAUDE_DIR"/hooks/*|\
    "$CODEX_DIR"/agents/*|\
    "$CODEX_DIR"/skills/*|\
    "$AGENTS_DIR"/skills/*|\
    "$FRAMEWORKS_DIR"/*|\
    "$BIN_DIR"/*|\
    "$INSTALL_DIR"/share/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Set RECOVERY_STATUS and RECOVERY_COUNT without printing retained paths. The
# state deliberately covers only installer-managed payloads, never Codex auth,
# MCP token caches, or other user configuration.
recovery_state_summary() {
  RECOVERY_STATUS=none
  RECOVERY_COUNT=0
  if [ ! -e "$RECOVERY_STATE_FILE" ]; then
    if [ -d "$RECOVERY_ROOT" ] \
      && [ -n "$(find "$RECOVERY_ROOT" -mindepth 1 -print -quit 2>/dev/null)" ]; then
      RECOVERY_STATUS=attention-required
      return 1
    fi
    return 0
  fi

  [ -f "$RECOVERY_STATE_FILE" ] \
    && [ ! -L "$RECOVERY_STATE_FILE" ] \
    && [ "$(private_mode "$RECOVERY_STATE_FILE")" = 600 ] \
    && [ -d "$RECOVERY_ROOT" ] \
    && [ ! -L "$RECOVERY_ROOT" ] \
    && [ "$(private_mode "$RECOVERY_ROOT")" = 700 ] || {
      RECOVERY_STATUS=attention-required
      return 1
    }

  recovery_valid=1
  recovery_records=0
  while IFS='	' read -r recovery_run recovery_digest recovery_backup recovery_destination recovery_extra; do
    recovery_records=$((recovery_records + 1))
    [ -z "$recovery_extra" ] || recovery_valid=0
    printf '%s\n' "${recovery_run##*/}" \
      | grep -Eq '^[0-9]{8}T[0-9]{6}Z-[0-9]+$' \
      || recovery_valid=0
    case "$recovery_run" in "$RECOVERY_ROOT"/*) ;; *) recovery_valid=0 ;; esac
    [ "${recovery_backup%/*}" = "$recovery_run" ] || recovery_valid=0
    printf '%s\n' "${recovery_backup##*/}" \
      | grep -Eq '^backup-[1-9][0-9]*$' \
      || recovery_valid=0
    case "$recovery_digest" in *[!a-f0-9]*|'') recovery_valid=0 ;; esac
    [ "${#recovery_digest}" -eq 64 ] || recovery_valid=0
    recovery_destination_allowed "$recovery_destination" || recovery_valid=0
    [ -d "$recovery_run" ] \
      && [ ! -L "$recovery_run" ] \
      && [ "$(private_mode "$recovery_run")" = 700 ] \
      && [ -f "$recovery_backup" ] \
      && [ ! -L "$recovery_backup" ] \
      && [ "$(private_mode "$recovery_backup")" = 600 ] \
      && [ "$(sha256_file "$recovery_backup")" = "$recovery_digest" ] \
      || recovery_valid=0
  done < "$RECOVERY_STATE_FILE"

  recovery_files=$(find "$RECOVERY_ROOT" -type f 2>/dev/null | wc -l | tr -d '[:space:]')
  [ "$recovery_records" -gt 0 ] \
    && [ "$recovery_files" = "$recovery_records" ] \
    && [ "$recovery_valid" -eq 1 ] || {
      RECOVERY_STATUS=attention-required
      return 1
    }
  RECOVERY_STATUS=available
  RECOVERY_COUNT=$recovery_records
  return 0
}

check_recovery_backups() {
  if recovery_state_summary; then
    case "$RECOVERY_STATUS" in
      none) printf '%s\n' 'recovery: none retained' ;;
      available) printf 'recovery: %s retained forced-replacement backup(s)\n' "$RECOVERY_COUNT" ;;
    esac
    return 0
  fi
  printf '%s\n' 'recovery: attention-required'
  return 1
}
