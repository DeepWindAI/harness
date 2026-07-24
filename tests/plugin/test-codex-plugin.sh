#!/usr/bin/env bash
# Test fixtures intentionally preserve literal $HOME and ~/ path patterns.
# shellcheck disable=SC2016,SC2088
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
PLUGIN="$ROOT/plugins/deepwind-harness"
MARKETPLACE="$ROOT/.agents/plugins/marketplace.json"
POLICY_TEST="$ROOT/tests/plugin/assert-child-mcp-policy.sh"
ROLE_VALIDATOR="$ROOT/tests/validate_codex_toml.py"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -f "$PLUGIN/.codex-plugin/plugin.json" ] || fail 'plugin manifest is missing'
[ -f "$MARKETPLACE" ] || fail 'repo-local marketplace is missing'

jq -e '
  .name == "deepwind-harness" and
  (.version | test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")) and
  (.description | length > 20) and
  .author.name == "DeepWind" and
  .skills == "./skills/" and
  .interface.displayName == "DeepWind Harness" and
  .interface.developerName == "DeepWind" and
  (.interface.defaultPrompt | length >= 1 and length <= 3) and
  (has("hooks") | not) and
  (has("mcpServers") | not) and
  (has("apps") | not)
' "$PLUGIN/.codex-plugin/plugin.json" >/dev/null \
  || fail 'plugin manifest contract failed'

jq -e '
  .name == "deepwind" and
  (.plugins | length == 1) and
  .plugins[0].name == "deepwind-harness" and
  .plugins[0].source.source == "local" and
  .plugins[0].source.path == "./plugins/deepwind-harness" and
  .plugins[0].policy.installation == "AVAILABLE" and
  .plugins[0].policy.authentication == "ON_INSTALL" and
  (.plugins[0].policy | has("products") | not) and
  .plugins[0].category == "Developer Tools"
' "$MARKETPLACE" >/dev/null || fail 'repo-local marketplace contract failed'

expected_skills=$'harness-coordinator\nharness-discipline\nharness-planner\nharness-prep'
actual_skills=$(
  find "$PLUGIN/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -print \
    | sed -e "s#^$PLUGIN/skills/##" -e 's#/SKILL.md$##' \
    | LC_ALL=C sort
)
[ "$actual_skills" = "$expected_skills" ] || fail 'plugin must contain exactly four harness skills'

for skill in harness-prep harness-planner harness-coordinator harness-discipline; do
  file="$PLUGIN/skills/$skill/SKILL.md"
  first_name=$(sed -n 's/^name: //p' "$file" | head -1)
  [ "$first_name" = "$skill" ] || fail "$skill has invalid frontmatter"
  rg -q '^description: .+' "$file" || fail "$skill has no description"
  rg -q '^## MCP boundary$' "$file" || fail "$skill has no explicit MCP boundary"
done

if rg -n 'Skill\(|Task\(|~/.claude|CLAUDECODE|Claude Code agent' "$PLUGIN/skills"; then
  fail 'Claude-only invocation syntax remains in Codex skills'
fi

bash "$POLICY_TEST" "$ROOT" >/dev/null
python3 "$ROLE_VALIDATOR" "$ROOT/codex/agents" >/dev/null

fixture=$(mktemp -d "${TMPDIR:-/tmp}/deepwind-plugin-policy.XXXXXX")
trap 'find "$fixture" -depth -type f -exec rm -f {} \; 2>/dev/null || true; find "$fixture" -depth -type d -exec rmdir {} \; 2>/dev/null || true' EXIT
mkdir -p "$fixture/plugins/deepwind-harness/skills/child"

for forbidden in \
  'deepwind_query_backlog' \
  'https://example.test/mcp' \
  '$HOME/.mcp-auth/tokens.json' \
  'oauth_token_path' \
  'codex mcp login deepwind'
do
  printf '%s\n' "$forbidden" > "$fixture/plugins/deepwind-harness/skills/child/SKILL.md"
  if bash "$POLICY_TEST" "$fixture" >/dev/null 2>&1; then
    fail "policy scanner accepted forbidden content: $forbidden"
  fi
done

mkdir -p "$fixture/codex/agents"
printf '%s\n' \
  'name = "unsafe-child"' \
  'description = "Unsafe connector-configured child fixture."' \
  'developer_instructions = "This fixture exists only to prove that child-specific connector configuration is rejected by static policy."' \
  'sandbox_mode = "read-only"' \
  '[mcp_servers.remote]' \
  'command = "printf"' \
  > "$fixture/codex/agents/unsafe-child.toml"
if bash "$POLICY_TEST" "$fixture" >/dev/null 2>&1; then
  fail 'policy scanner accepted child-specific connector configuration'
fi

rg -q 'codex plugin marketplace add' "$PLUGIN/README.md" \
  || fail 'fresh-install lifecycle command is absent'
rg -q 'codex plugin add' "$PLUGIN/README.md" \
  || fail 'enable/upgrade lifecycle command is absent'
rg -q 'codex plugin list --json' "$PLUGIN/README.md" \
  || fail 'check lifecycle command is absent'
rg -q 'codex plugin remove' "$PLUGIN/README.md" \
  || fail 'removal lifecycle command is absent'
rg -q 'Copying .* does not install' "$PLUGIN/README.md" \
  || fail 'plugin docs may imply copying is installation'
if rg -n '~/.agents/plugins/marketplace.json|personal marketplace' "$PLUGIN/README.md"; then
  fail 'plugin lifecycle must not write a personal marketplace'
fi

rg -q 'build_target codex .*\.agents/plugins/marketplace\.json plugins/deepwind-harness' \
  "$ROOT/.github/workflows/weekly-release.yml" \
  || fail 'Codex release archive does not contain its marketplace and plugin together'
rg -q '\.version = \$version' "$ROOT/.github/workflows/weekly-release.yml" \
  || fail 'release build does not align plugin semver with the immutable release'
rg -q 'CODEX_MARKETPLACE_DIR' "$ROOT/lib/state.sh" \
  || fail 'installer has no release-contained Codex marketplace root'
rg -q 'codex:\.agents/plugins/marketplace\.json' "$ROOT/lib/install-target.sh" \
  || fail 'installer does not map the release-contained marketplace'
rg -q -- '--enable-codex-plugin' "$ROOT/lib/args.sh" \
  || fail 'installer does not expose explicit plugin lifecycle opt-in'
rg -q 'codex plugin marketplace add "\$CODEX_MARKETPLACE_DIR" --json' \
  "$ROOT/lib/codex-plugin.sh" \
  || fail 'installer does not use fixed argv for marketplace activation'
rg -q 'codex plugin add deepwind-harness@deepwind --json' \
  "$ROOT/lib/codex-plugin.sh" \
  || fail 'installer does not use fixed argv for plugin activation'

printf 'PASS: Codex plugin package and policy tests\n'
