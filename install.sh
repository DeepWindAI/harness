#!/usr/bin/env bash
#
# Manual install — copies this repo's contents into ~/.claude/ and
# ~/pm33-frameworks/. Equivalent to the curl-pipe-bash flow on pm-33.com,
# but driven from a local clone (good for forks, air-gapped, or anyone
# who'd rather inspect-then-run).
#
# Run from the repo root:
#     git clone https://github.com/DeepWindAI/harness.git
#     cd harness
#     ./install.sh
#
# Idempotent: re-running overwrites the PM33-managed files but leaves
# anything else under ~/.claude/ untouched. Writes only under $HOME;
# never sudo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
FRAMEWORKS_DIR="${DEEPWIND_FRAMEWORKS_DIR:-$HOME/deepwind-frameworks}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }

bold "DeepWind Harness — local install"
echo

mkdir -p "$CLAUDE_DIR/agents" "$CLAUDE_DIR/skills" "$FRAMEWORKS_DIR"

for src in "$SCRIPT_DIR/agents/"*.md "$SCRIPT_DIR/agents/LICENSE.wshobson"; do
  [ -e "$src" ] || continue
  fname=$(basename "$src")
  cp "$src" "$CLAUDE_DIR/agents/$fname"
  ok "agents/$fname"
done

for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  dest="$CLAUDE_DIR/skills/$skill_name"
  rm -rf "$dest"
  cp -r "$skill_dir" "$dest"
  ok "skills/$skill_name/"
done

for src in "$SCRIPT_DIR/frameworks/"*; do
  [ -e "$src" ] || continue
  fname=$(basename "$src")
  cp "$src" "$FRAMEWORKS_DIR/$fname"
  ok "frameworks/$fname"
done

cp "$SCRIPT_DIR/README.md"          "$FRAMEWORKS_DIR/README.md"
cp "$SCRIPT_DIR/CLAUDE.md.starter"  "$FRAMEWORKS_DIR/CLAUDE.md.starter"
ok "README.md (bundle docs)"
ok "CLAUDE.md.starter"

echo
bold "Done."
echo
echo "  Read first:  $FRAMEWORKS_DIR/README.md"
echo "  Copy into your project root (and edit):"
echo "               $FRAMEWORKS_DIR/CLAUDE.md.starter → ./CLAUDE.md"
echo
echo "  Connect the DeepWind MCP:"
echo "    1. Restart Claude Code"
echo "    2. /mcp → \"claude.ai PM33\" → complete OAuth"
echo "    3. Before first pm33_* call: Skill({ skill: \"deepwind-mcp\" })"
echo
