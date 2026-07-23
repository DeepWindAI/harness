# shellcheck shell=bash disable=SC2034
# Argument parsing for the standalone DeepWind installer.

usage() {
  cat <<'EOF'
usage: deepwind-init.sh [options]
  --target claude|codex|both  install target (default: both)
  --version SEMVER            install an exact immutable release
  --channel staging|production
  --dry-run                   verify and print changes without writing
  --check                     verify and report drift without writing
  --force                     replace locally modified managed files
  --skip-hooks                do not install Claude session hooks
  -h, --help
EOF
}

parse_args() {
  TARGET=both
  VERSION=
  CHANNEL=staging
  MODE=install
  FORCE=0
  SKIP_HOOKS=0

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --target)
        [ "$#" -ge 2 ] || die "--target requires a value"
        TARGET=$2
        shift 2
        ;;
      --version)
        [ "$#" -ge 2 ] || die "--version requires a value"
        VERSION=$2
        shift 2
        ;;
      --channel)
        [ "$#" -ge 2 ] || die "--channel requires a value"
        CHANNEL=$2
        shift 2
        ;;
      --dry-run)
        [ "$MODE" = install ] || die "--dry-run and --check are mutually exclusive"
        MODE=dry-run
        shift
        ;;
      --check)
        [ "$MODE" = install ] || die "--dry-run and --check are mutually exclusive"
        MODE=check
        shift
        ;;
      --force)
        FORCE=1
        shift
        ;;
      --skip-hooks)
        SKIP_HOOKS=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --ref|--configure-mcp|--uninstall)
        die "unsupported option in the safe installer: $1"
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done

  case "$TARGET" in claude|codex|both) ;; *) die "target must be claude, codex, or both" ;; esac
  case "$CHANNEL" in staging|production) ;; *) die "channel must be staging or production" ;; esac
  if [ -n "$VERSION" ]; then
    printf '%s' "$VERSION" | grep -Eq \
      '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$' \
      || die "version must be strict semver"
  fi
}
