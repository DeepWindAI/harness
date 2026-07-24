#!/usr/bin/env bash
# Shell tests for the release manifest builder.  They deliberately use only
# temporary fixture archives so they can run without credentials or network.
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD="$ROOT/release/build-manifest.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/deepwind-manifest-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_fail() {
  if "$@" >/dev/null 2>&1; then
    fail "expected command to fail: $*"
  fi
}
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

mkdir -p "$TMP/claude/agents" "$TMP/codex/plugins"
printf 'claude role\n' > "$TMP/claude/agents/coordinator.md"
printf 'codex plugin\n' > "$TMP/codex/plugins/plugin.json"
tar -C "$TMP/claude" -czf "$TMP/deepwind-harness-claude-v1.2.3.tar.gz" .
tar -C "$TMP/codex" -czf "$TMP/deepwind-harness-codex-v1.2.3.tar.gz" .
printf '#!/usr/bin/env bash\nprintf "DeepWind bootstrap\\n"\n' > "$TMP/deepwind-init-v1.2.3.sh"
chmod 755 "$TMP/deepwind-init-v1.2.3.sh"

# RED evidence: before DW-001 implementation this invocation fails because the
# builder does not exist.  Once it exists all remaining assertions are GREEN.
"$BUILD" \
  --version 1.2.3 \
  --channel staging \
  --endpoint-alias deepwind-staging \
  --endpoint-url https://dev.deepwind.ai/mcp \
  --key-id test-key \
  --not-before 2026-01-01T00:00:00Z \
  --not-after 2027-01-01T00:00:00Z \
  --source-revision deadbeef \
  --bootstrap "$TMP/deepwind-init-v1.2.3.sh" \
  --archive "claude=$TMP/deepwind-harness-claude-v1.2.3.tar.gz" \
  --archive "codex=$TMP/deepwind-harness-codex-v1.2.3.tar.gz" \
  --output "$TMP/manifest-a.json"

"$BUILD" \
  --version 1.2.3 --channel staging --endpoint-alias deepwind-staging \
  --endpoint-url https://dev.deepwind.ai/mcp --key-id test-key \
  --not-before 2026-01-01T00:00:00Z --not-after 2027-01-01T00:00:00Z \
  --source-revision deadbeef \
  --bootstrap "$TMP/deepwind-init-v1.2.3.sh" \
  --archive "claude=$TMP/deepwind-harness-claude-v1.2.3.tar.gz" \
  --archive "codex=$TMP/deepwind-harness-codex-v1.2.3.tar.gz" \
  --output "$TMP/manifest-b.json"

cmp "$TMP/manifest-a.json" "$TMP/manifest-b.json" || fail 'same input must produce byte-identical manifest'
jq -e --arg c "$(sha256 "$TMP/deepwind-harness-claude-v1.2.3.tar.gz")" \
  '.archives[] | select(.target == "claude") | .sha256 == $c' "$TMP/manifest-a.json" >/dev/null || fail 'claude digest missing'
jq -e --arg sha "$(sha256 "$TMP/deepwind-init-v1.2.3.sh")" \
  --argjson bytes "$(wc -c < "$TMP/deepwind-init-v1.2.3.sh" | tr -d '[:space:]')" '
    .bootstrap == {
      file: "deepwind-init-v1.2.3.sh",
      sha256: $sha,
      bytes: $bytes
    }
  ' "$TMP/manifest-a.json" >/dev/null || fail 'versioned bootstrap contract missing'
jq -e '(.archives | length == 2) and (.endpoint.alias == "deepwind-staging")' "$TMP/manifest-a.json" >/dev/null || fail 'required manifest fields missing'
jq -e --slurpfile schema "$ROOT/release/manifest.schema.json" '.' "$TMP/manifest-a.json" >/dev/null || fail 'manifest is not JSON'

mkdir -p "$TMP/bad/../escape" 2>/dev/null || true
printf 'bad\n' > "$TMP/bad-file"
tar -C "$TMP" -s ',bad-file,../escape,' -czf "$TMP/traversal.tar.gz" bad-file
mkdir -p "$TMP/duplicate"
tar -C "$TMP/claude" -czf "$TMP/duplicate/deepwind-harness-claude-v1.2.3.tar.gz" agents/coordinator.md agents/coordinator.md
expect_fail "$BUILD" --version 1.2.3 --channel staging --endpoint-alias deepwind-staging \
  --endpoint-url https://dev.deepwind.ai/mcp --key-id test-key \
  --not-before 2026-01-01T00:00:00Z --not-after 2027-01-01T00:00:00Z \
  --source-revision deadbeef --bootstrap "$TMP/deepwind-init-v1.2.3.sh" \
  --archive "claude=$TMP/traversal.tar.gz" --output "$TMP/bad.json"
expect_fail "$BUILD" --version 1.2.3 --channel staging --endpoint-alias deepwind-staging \
  --endpoint-url https://dev.deepwind.ai/mcp --key-id test-key \
  --not-before 2026-01-01T00:00:00Z --not-after 2027-01-01T00:00:00Z \
  --source-revision deadbeef --bootstrap "$TMP/deepwind-init-v1.2.3.sh" \
  --archive "claude=$TMP/duplicate/deepwind-harness-claude-v1.2.3.tar.gz" --output "$TMP/bad.json"
expect_fail "$BUILD" --version not-semver --channel staging --endpoint-alias deepwind-staging \
  --endpoint-url https://dev.deepwind.ai/mcp --key-id test-key \
  --not-before 2026-01-01T00:00:00Z --not-after 2027-01-01T00:00:00Z \
  --source-revision deadbeef --bootstrap "$TMP/deepwind-init-v1.2.3.sh" \
  --archive "claude=$TMP/deepwind-harness-claude-v1.2.3.tar.gz" --output "$TMP/bad.json"
expect_fail "$BUILD" --version 1.2.3 --channel staging --endpoint-alias deepwind-staging \
  --endpoint-url https://dev.deepwind.ai/mcp --key-id '' \
  --not-before 2026-01-01T00:00:00Z --not-after 2027-01-01T00:00:00Z \
  --source-revision deadbeef --bootstrap "$TMP/deepwind-init-v1.2.3.sh" \
  --archive "claude=$TMP/deepwind-harness-claude-v1.2.3.tar.gz" --output "$TMP/bad.json"
cp "$TMP/deepwind-init-v1.2.3.sh" "$TMP/deepwind-init.sh"
expect_fail "$BUILD" --version 1.2.3 --channel staging --endpoint-alias deepwind-staging \
  --endpoint-url https://dev.deepwind.ai/mcp --key-id test-key \
  --not-before 2026-01-01T00:00:00Z --not-after 2027-01-01T00:00:00Z \
  --source-revision deadbeef --bootstrap "$TMP/deepwind-init.sh" \
  --archive "claude=$TMP/deepwind-harness-claude-v1.2.3.tar.gz" --output "$TMP/bad.json"

printf 'PASS: release manifest tests\n'
