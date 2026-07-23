# shellcheck shell=bash disable=SC2034
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
  FRAMEWORKS_DIR="$HOME/deepwind-frameworks"
  INSTALL_DIR="$HOME/.deepwind/install"
  CODEX_MARKETPLACE_DIR="$INSTALL_DIR/share/codex-marketplace"
  BIN_DIR="$HOME/.deepwind/bin"
  LOCK_DIR="$HOME/.deepwind-install.lock"
  STATE_FILE="$INSTALL_DIR/state.tsv"
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
