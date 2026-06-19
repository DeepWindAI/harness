#!/usr/bin/env bash
# session-start-deepwind-version-check.sh
# Daily check of the public deepwind-install repo's VERSION against what the
# installer wrote locally. Advisory only — NEVER blocks, NEVER errors out.
#
# Installed by: deepwind-init.sh (copies into <repo>/.claude/hooks/ and adds
# itself to .claude/settings.json's SessionStart array).
#
# Lifecycle: runs at every Claude Code session start. Hits the network at
# most once per 24 hours (cache file: $HOME/.cache/deepwind/version.json).
#
# Output: stderr banner ONLY when a newer version exists. Silent otherwise.
#
# Disable per-session:  DEEPWIND_VERSION_CHECK=0
# Disable permanently:  rm <repo>/.claude/hooks/session-start-deepwind-version-check.sh
#                       (and re-run deepwind-init.sh next time you want it back)

set -euo pipefail

[ "${DEEPWIND_VERSION_CHECK:-1}" = "0" ] && exit 0

# Consume hook stdin (SessionStart hook protocol sends a JSON payload).
cat > /dev/null || true

# Where the installer wrote the locally-installed version. If absent, the user
# didn't install via deepwind-init — exit silent rather than nag.
LOCAL_VERSION_FILE="$HOME/.deepwind/install/VERSION"
[ -f "$LOCAL_VERSION_FILE" ] || exit 0

LOCAL_VERSION="$(tr -d '[:space:]' < "$LOCAL_VERSION_FILE" 2>/dev/null || echo "")"
[ -z "$LOCAL_VERSION" ] && exit 0

# Public manifest URL. The installer pins this at install time so a future
# repo rename doesn't strand existing installs. Override via env for testing.
MANIFEST_URL="${DEEPWIND_VERSION_MANIFEST_URL:-https://raw.githubusercontent.com/deepwind/deepwind-install/main/VERSION}"

CACHE_DIR="$HOME/.cache/deepwind"
CACHE_FILE="$CACHE_DIR/version.json"
mkdir -p "$CACHE_DIR" 2>/dev/null || exit 0  # cache-dir failure → silent skip

NOW=$(date +%s)
TTL=86400  # 24h
REMOTE_VERSION=""

# 1. Try cache first.
if [ -f "$CACHE_FILE" ] && command -v jq >/dev/null 2>&1; then
  CACHED_AT=$(jq -r '.checkedAt // 0' "$CACHE_FILE" 2>/dev/null || echo 0)
  AGE=$((NOW - CACHED_AT))
  if [ "$AGE" -ge 0 ] && [ "$AGE" -lt "$TTL" ]; then
    REMOTE_VERSION=$(jq -r '.latest // ""' "$CACHE_FILE" 2>/dev/null || echo "")
  fi
fi

# 2. Cache miss / expired → fetch with hard 2s timeout so a slow network never
#    blocks session start. Failures cache the *attempt* to avoid hammering
#    GitHub when offline.
if [ -z "$REMOTE_VERSION" ]; then
  REMOTE_VERSION=$(curl -fsSL --max-time 2 "$MANIFEST_URL" 2>/dev/null \
    | tr -d '[:space:]' \
    || echo "")
  if command -v jq >/dev/null 2>&1; then
    if [ -n "$REMOTE_VERSION" ]; then
      jq -nc --arg v "$REMOTE_VERSION" --argjson t "$NOW" \
        '{latest:$v, checkedAt:$t}' > "$CACHE_FILE" 2>/dev/null || true
    else
      # Cache the failed attempt for 1h so we don't hit GH on every session start
      # when the user is offline. (Shorter TTL than success.)
      jq -nc --arg v "" --argjson t "$NOW" --argjson f 1 \
        '{latest:$v, checkedAt:($t - 82800), failed:$f}' > "$CACHE_FILE" 2>/dev/null || true
    fi
  fi
fi

# Nothing to compare against — silent.
[ -z "$REMOTE_VERSION" ] && exit 0
[ "$LOCAL_VERSION" = "$REMOTE_VERSION" ] && exit 0

# Compare with `sort -V` (version sort). Only prompt when remote is STRICTLY
# newer than local. This avoids nagging users on a dev/pre-release build
# whose pinned version is ahead of the public manifest.
LOWER=$(printf '%s\n%s\n' "$LOCAL_VERSION" "$REMOTE_VERSION" | sort -V | head -n1)
if [ "$LOWER" != "$LOCAL_VERSION" ]; then
  # Local is newer (dev build / pre-release) — don't nag.
  exit 0
fi

# Remote is newer — emit advisory banner.
{
  echo "[deepwind] new version available: $LOCAL_VERSION → $REMOTE_VERSION"
  echo "           update:  curl -fsSL https://deepwind.ai/install/deepwind-init.sh | bash"
  echo "           changes: https://github.com/deepwind/deepwind-install/releases/tag/v$REMOTE_VERSION"
  echo "           silence: DEEPWIND_VERSION_CHECK=0  (or set in your shell rc)"
} >&2

exit 0
