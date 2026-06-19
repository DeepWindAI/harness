#!/usr/bin/env bash
# deepwind-init.sh — DeepWind installer entry point (curl-bash).
#
# Hosted at: https://deepwind.ai/install/deepwind-init.sh
# Source:    https://github.com/DeepWindAI/harness/blob/main/deepwind-init.sh
#
# Invocation:
#   curl -fsSL https://deepwind.ai/install/deepwind-init.sh | bash
#   curl -fsSL https://deepwind.ai/install/deepwind-init.sh | bash -s -- --check
#   curl -fsSL https://deepwind.ai/install/deepwind-init.sh | bash -s -- --skip-hooks
#   curl -fsSL https://deepwind.ai/install/deepwind-init.sh | bash -s -- --version 1.1.0
#
# What it installs (idempotent — safe to re-run):
#   1. DeepWind MCP server entry in ~/.claude.json (hosted SSE, OAuth on first use)
#   2. Harness skills bundle into ~/.claude/skills/
#      (harness-coordinator, harness-discipline, harness-planner, harness-prep,
#       harness-discovery, harness-research, gauntlet-review, feature-enhancements,
#       deepwind-mcp, deepwind-mcp-queue)
#   3. Subagents into ~/.claude/agents/
#   4. Frameworks (templates) into ~/deepwind-frameworks/
#   5. (Default ON) Version-check hook into ~/.claude/hooks/ — emits a stderr
#      banner once per day when a newer install is available.
#   6. Local version marker at ~/.deepwind/install/VERSION
#
# Flags:
#   --check         Print what would be installed, then exit 0
#   --skip-hooks    Skip step 5 (version-check hook). Useful for CI / air-gapped.
#   --version <v>   Pin to a specific release tag (default: latest VERSION on main)
#   --ref <ref>     Pin to a git ref (commit SHA / branch). Mutually exclusive with --version.
#   --uninstall     Print uninstall instructions (no automatic file removal — safer)

set -euo pipefail

# ----------------------------------------------------------------------------
# Configuration — env-overridable so a future repo move doesn't strand installs
# ----------------------------------------------------------------------------
REPO_OWNER="${DEEPWIND_INSTALL_OWNER:-DeepWindAI}"
REPO_NAME="${DEEPWIND_INSTALL_REPO:-harness}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}"
DEFAULT_REF="main"

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
FRAMEWORKS_DIR="${DEEPWIND_FRAMEWORKS_DIR:-$HOME/deepwind-frameworks}"
INSTALL_DIR="$HOME/.deepwind/install"
CACHE_DIR="$HOME/.cache/deepwind"

# ----------------------------------------------------------------------------
# Flags
# ----------------------------------------------------------------------------
MODE="install"
SKIP_HOOKS=0
PIN_VERSION=""
PIN_REF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)      MODE="check"; shift ;;
    --skip-hooks) SKIP_HOOKS=1; shift ;;
    --version)    PIN_VERSION="$2"; shift 2 ;;
    --ref)        PIN_REF="$2"; shift 2 ;;
    --uninstall)  MODE="uninstall"; shift ;;
    -h|--help)    sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            echo "deepwind-init: unknown flag '$1'" >&2; exit 2 ;;
  esac
done

# ----------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

# ----------------------------------------------------------------------------
# Preflight
# ----------------------------------------------------------------------------
preflight() {
  command -v curl >/dev/null 2>&1 || { err "curl is required"; exit 3; }
  command -v jq   >/dev/null 2>&1 || { err "jq is required (brew install jq / apt-get install jq)"; exit 3; }
}

# ----------------------------------------------------------------------------
# Resolve target ref
# ----------------------------------------------------------------------------
resolve_ref() {
  if [[ -n "$PIN_REF" && -n "$PIN_VERSION" ]]; then
    err "--version and --ref are mutually exclusive"; exit 2
  fi
  [[ -n "$PIN_REF" ]] && { echo "$PIN_REF"; return; }
  [[ -n "$PIN_VERSION" ]] && { echo "v$PIN_VERSION"; return; }
  local v
  v=$(curl -fsSL --max-time 10 "${RAW_BASE}/${DEFAULT_REF}/VERSION" 2>/dev/null | tr -d '[:space:]')
  [[ -n "$v" ]] && { echo "v$v"; return; }
  warn "could not fetch VERSION manifest; falling back to '${DEFAULT_REF}'"
  echo "$DEFAULT_REF"
}

# ----------------------------------------------------------------------------
# Fetch a single file
# ----------------------------------------------------------------------------
fetch() {
  local rel_path="$1" dest="$2"
  local url="${RAW_BASE}/${RESOLVED_REF}/${rel_path}"
  mkdir -p "$(dirname "$dest")"
  if ! curl -fsSL --max-time 30 "$url" -o "$dest.tmp"; then
    err "failed: $url"
    rm -f "$dest.tmp"; return 1
  fi
  mv "$dest.tmp" "$dest"
}

# ----------------------------------------------------------------------------
# Fetch a directory by listing the GitHub tree API + downloading each blob.
# Stays portable (no git, no svn). Filters by prefix.
# ----------------------------------------------------------------------------
fetch_tree() {
  local prefix="$1" dest_root="$2"
  local api="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/trees/${RESOLVED_REF}?recursive=true"
  local list
  list=$(curl -fsSL --max-time 30 "$api" 2>/dev/null \
    | jq -r --arg p "$prefix/" \
        '.tree[] | select(.type=="blob") | select(.path | startswith($p)) | .path')
  if [[ -z "$list" ]]; then
    warn "no files under $prefix in ${RESOLVED_REF}"
    return 1
  fi
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    local rel="${path#$prefix/}"
    fetch "$path" "$dest_root/$rel" || true
  done <<< "$list"
}

# ----------------------------------------------------------------------------
# Install steps
# ----------------------------------------------------------------------------
step_skills() {
  bold "Skills → $CLAUDE_DIR/skills/"
  mkdir -p "$CLAUDE_DIR/skills"
  local skills=(
    harness-coordinator harness-discipline harness-planner harness-prep
    harness-discovery harness-research gauntlet-review feature-enhancements
    deepwind-mcp deepwind-mcp-queue
  )
  for s in "${skills[@]}"; do
    rm -rf "$CLAUDE_DIR/skills/$s"
    if fetch_tree "skills/$s" "$CLAUDE_DIR/skills/$s"; then
      ok "$s"
    else
      warn "$s — skipped"
    fi
  done
}

step_agents() {
  bold "Subagents → $CLAUDE_DIR/agents/"
  mkdir -p "$CLAUDE_DIR/agents"
  fetch_tree "agents" "$CLAUDE_DIR/agents" && ok "agents"
}

step_frameworks() {
  bold "Frameworks → $FRAMEWORKS_DIR/"
  mkdir -p "$FRAMEWORKS_DIR"
  fetch_tree "frameworks" "$FRAMEWORKS_DIR" && ok "frameworks"
  fetch "README.md"         "$FRAMEWORKS_DIR/README.md"         && ok "README.md"
  fetch "CLAUDE.md.starter" "$FRAMEWORKS_DIR/CLAUDE.md.starter" && ok "CLAUDE.md.starter"
}

step_mcp() {
  bold "MCP server config → ~/.claude.json (mcpServers.deepwind)"
  local target="$HOME/.claude.json"
  [[ -f "$target" ]] || echo '{}' > "$target"
  cp "$target" "$target.deepwind-backup.$(date +%s)"
  fetch "payload/mcp/deepwind.mcp.json" "$CACHE_DIR/deepwind.mcp.json"
  jq --slurpfile entry "$CACHE_DIR/deepwind.mcp.json" \
     '.mcpServers //= {} | .mcpServers.deepwind = $entry[0]' \
     "$target" > "$target.new"
  mv "$target.new" "$target"
  ok "merged DeepWind SSE entry (OAuth on first /mcp use)"
}

step_hooks() {
  bold "Version-check hook → $CLAUDE_DIR/hooks/"
  mkdir -p "$CLAUDE_DIR/hooks"
  fetch "payload/hooks/session-start-deepwind-version-check.sh" \
        "$CLAUDE_DIR/hooks/session-start-deepwind-version-check.sh"
  chmod +x "$CLAUDE_DIR/hooks/session-start-deepwind-version-check.sh"
  ok "session-start-deepwind-version-check.sh"
  warn "Add to .claude/settings.json's SessionStart hooks array to activate:"
  warn '  { "type": "command", "command": ".claude/hooks/session-start-deepwind-version-check.sh" }'
}

step_version_marker() {
  mkdir -p "$INSTALL_DIR"
  local v="${RESOLVED_REF#v}"
  echo "$v" > "$INSTALL_DIR/VERSION"
  date -u +%FT%TZ > "$INSTALL_DIR/INSTALLED_AT"
  echo "$RESOLVED_REF" > "$INSTALL_DIR/REF"
  ok "version marker: $INSTALL_DIR/VERSION ($v)"
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
main() {
  preflight
  mkdir -p "$CACHE_DIR"
  RESOLVED_REF=$(resolve_ref)

  case "$MODE" in
    check)
      bold "deepwind-init: dry-run for ref $RESOLVED_REF"
      echo "  skills:     $CLAUDE_DIR/skills/{harness-*, gauntlet-review, feature-enhancements, deepwind-mcp, deepwind-mcp-queue}"
      echo "  agents:     $CLAUDE_DIR/agents/"
      echo "  frameworks: $FRAMEWORKS_DIR/"
      echo "  MCP:        ~/.claude.json (mcpServers.deepwind, hosted SSE + OAuth)"
      [[ $SKIP_HOOKS -eq 0 ]] && echo "  hook:       $CLAUDE_DIR/hooks/session-start-deepwind-version-check.sh"
      echo "  marker:     $INSTALL_DIR/VERSION"
      exit 0
      ;;
    uninstall)
      bold "Uninstall — manual (safer than automatic)"
      echo "  rm -rf $CLAUDE_DIR/skills/{harness-*,gauntlet-review,feature-enhancements,deepwind-mcp,deepwind-mcp-queue}"
      echo "  rm -rf $CLAUDE_DIR/agents/{ai-engineer,backend-architect,code-reviewer,database-admin,frontend-developer,harness-coordinator,harness-planner-agent,performance-engineer,security-auditor,test-automator,ui-ux-designer}.md"
      echo "  rm -rf $FRAMEWORKS_DIR"
      echo "  rm -f $CLAUDE_DIR/hooks/session-start-deepwind-version-check.sh"
      echo "  rm -rf $INSTALL_DIR $CACHE_DIR"
      echo "  jq 'del(.mcpServers.deepwind)' ~/.claude.json > /tmp/c && mv /tmp/c ~/.claude.json"
      exit 0
      ;;
    install)
      bold "DeepWind harness — installing $RESOLVED_REF"
      echo
      step_skills
      step_agents
      step_frameworks
      step_mcp
      [[ $SKIP_HOOKS -eq 0 ]] && step_hooks
      step_version_marker
      echo
      bold "Done."
      echo
      echo "  Next:"
      echo "    1. Restart Claude Code to pick up MCP changes"
      echo "    2. /mcp → \"DeepWind\" → complete OAuth"
      echo "    3. Read first: $FRAMEWORKS_DIR/README.md"
      echo "    4. Copy into your project root: $FRAMEWORKS_DIR/CLAUDE.md.starter → ./CLAUDE.md"
      echo
      echo "  Silence version checks: export DEEPWIND_VERSION_CHECK=0"
      ;;
  esac
}

main "$@"
