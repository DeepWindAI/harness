#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT=${1:-.}

scan_paths=()
if [ -d "$ROOT/plugins/deepwind-harness/skills" ]; then
  scan_paths+=("$ROOT/plugins/deepwind-harness/skills")
fi
if [ -d "$ROOT/codex/agents" ]; then
  scan_paths+=("$ROOT/codex/agents")
fi

[ "${#scan_paths[@]}" -gt 0 ] || {
  printf 'policy scan found no Codex child skill or role paths\n' >&2
  exit 2
}

for pattern in \
  'deepwind_[[:alnum:]_]*' \
  'https://[^[:space:]"'"'"']*/mcp([/?#][^[:space:]"'"'"']*)?' \
  '(^|[^[:alnum:]_])\.mcp-auth([^[:alnum:]_]|$)' \
  '(oauth|token)[_-]?(path|file|dir|directory|store)' \
  'codex[[:space:]]+mcp[[:space:]]+login'
do
  if LC_ALL=C rg -n -i --glob '*.md' --glob '*.toml' \
    --regexp "$pattern" "${scan_paths[@]}"; then
    printf 'forbidden child MCP capability matched: %s\n' "$pattern" >&2
    exit 1
  fi
done

printf 'PASS: child skills and roles contain no direct MCP capability\n'
