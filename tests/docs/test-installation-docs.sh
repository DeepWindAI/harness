#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for document in README.md docs/installation.md docs/codex.md docs/upgrading.md; do
  [ -f "$ROOT/$document" ] || fail "missing canonical document: $document"
done

for document in "$ROOT/README.md" "$ROOT/docs/installation.md"; do
  rg -Fq 'curl -fsSL https://deepwind.ai/install | bash' "$document" \
    || fail "missing public curl entry point in $document"
done

for target in claude codex both; do
  rg -Fq "$target" "$ROOT/docs/installation.md" \
    || fail "installation guide does not document target choice: $target"
done
rg -Fq -- '--check' "$ROOT/docs/upgrading.md" \
  || fail 'upgrade guide does not document check mode'
rg -Fq -- '--force' "$ROOT/docs/upgrading.md" \
  || fail 'upgrade guide does not document force-and-backup behavior'
rg -Fq '~/.deepwind/install/recovery/' "$ROOT/docs/upgrading.md" \
  || fail 'upgrade guide does not document durable forced-replacement recovery'
rg -Fq -- '--enable-codex-plugin' "$ROOT/docs/codex.md" \
  || fail 'Codex guide does not document one-command plugin opt-in'
rg -Fq -- '--configure-mcp' "$ROOT/docs/codex.md" \
  || fail 'Codex guide does not document explicit MCP onboarding'
rg -Fq 'no-workspace' "$ROOT/docs/codex.md" \
  || fail 'Codex guide does not document the nonfatal no-workspace doctor state'
rg -Fq 'coordinator' "$ROOT/docs/codex.md" \
  || fail 'Codex guide does not document coordinator MCP ownership'
rg -Fq 'TLS trust boundary' "$ROOT/docs/installation.md" \
  || fail 'installation guide does not document bootstrap trust boundary'

if rg -ni 'capeable-init|mcp\.deepwind\.ai/v1/sse' \
  "$ROOT/README.md" "$ROOT/docs"; then
  fail 'legacy installer or SSE endpoint remains in canonical documentation'
fi

printf 'PASS: canonical installer documentation contract\n'
