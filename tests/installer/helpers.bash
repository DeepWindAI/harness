#!/usr/bin/env bash
# shellcheck disable=SC2016

TEST_ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
FIXTURE_CODEX_ROLES='frontend-developer
harness-coordinator
harness-planner
security-auditor'

test_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

make_fixture_release() {
  FIXTURE_ROOT=$(realpath "$(mktemp -d "${TMPDIR:-/tmp}/deepwind-installer-test.XXXXXX")")
  FIXTURE_HOME="$FIXTURE_ROOT/home"
  FIXTURE_RELEASE="$FIXTURE_ROOT/release"
  FIXTURE_INSTALLER="$FIXTURE_ROOT/deepwind-init.sh"
  mkdir -p \
    "$FIXTURE_HOME" \
    "$FIXTURE_HOME/tmp" \
    "$FIXTURE_ROOT/bin" \
    "$FIXTURE_RELEASE/claude/agents" \
    "$FIXTURE_RELEASE/claude/skills/harness-prep" \
    "$FIXTURE_RELEASE/claude/skills/deepwind-harness-prep" \
    "$FIXTURE_RELEASE/codex/.agents/plugins" \
    "$FIXTURE_RELEASE/codex/plugins/deepwind-harness/.codex-plugin" \
    "$FIXTURE_RELEASE/codex/plugins/deepwind-harness/skills/deepwind-harness-prep" \
    "$FIXTURE_RELEASE/codex/codex/agents"
  printf 'fixture trusted keyring\n' > "$FIXTURE_ROOT/test-keyring.gpg"
  bash "$TEST_ROOT/release/build-installer.sh" \
    "$FIXTURE_INSTALLER" "$FIXTURE_ROOT/test-keyring.gpg"
  # shellcheck disable=SC2016
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    '[ "$1" = "--keyring" ]' \
    '[ -s "$2" ]' \
    '[ "$(cat "$3")" = "TEST-SIGNATURE" ]' \
    '[ -s "$4" ]' > "$FIXTURE_ROOT/bin/gpgv"
  chmod 755 "$FIXTURE_ROOT/bin/gpgv"

  # These seams make it a test failure if an ordinary fixture installation
  # reaches a real network or either host CLI. They write only within HOME.
  for fixture_tool in curl wget openssl codex claude; do
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -eu' \
      ': "${HOME:?}"' \
      'printf "%s\\n" "${0##*/}" >> "$HOME/.deepwind-test-tool-invocations"' \
      'exit 97' > "$FIXTURE_ROOT/bin/$fixture_tool"
    chmod 755 "$FIXTURE_ROOT/bin/$fixture_tool"
  done

  printf 'claude-agent-v1\n' > "$FIXTURE_RELEASE/claude/agents/harness-coordinator.md"
  printf 'claude-skill-v1\n' > "$FIXTURE_RELEASE/claude/skills/harness-prep/SKILL.md"
  printf 'claude-alias-skill-v1\n' > "$FIXTURE_RELEASE/claude/skills/deepwind-harness-prep/SKILL.md"
  printf '{"name":"deepwind-harness"}\n' \
    > "$FIXTURE_RELEASE/codex/plugins/deepwind-harness/.codex-plugin/plugin.json"
  printf 'codex-formal-skill-v1\n' \
    > "$FIXTURE_RELEASE/codex/plugins/deepwind-harness/skills/deepwind-harness-prep/SKILL.md"
  printf '{"name":"deepwind","plugins":[]}\n' \
    > "$FIXTURE_RELEASE/codex/.agents/plugins/marketplace.json"
  while IFS= read -r role; do
    printf 'name = "%s"\ndescription = "Fixture role for installer behavior tests."\ndeveloper_instructions = "Fixture instructions long enough for installer behavior tests; this content changes only when an upgrade test requests it."\nsandbox_mode = "read-only"\n[mcp_servers]\n' \
      "$role" > "$FIXTURE_RELEASE/codex/codex/agents/$role.toml"
  done <<EOF
$FIXTURE_CODEX_ROLES
EOF

  tar -C "$FIXTURE_RELEASE/claude" -czf \
    "$FIXTURE_RELEASE/deepwind-harness-claude-v1.2.3.tar.gz" agents skills
  tar -C "$FIXTURE_RELEASE/codex" -czf \
    "$FIXTURE_RELEASE/deepwind-harness-codex-v1.2.3.tar.gz" .agents plugins codex

  claude_sha=$(test_sha256 "$FIXTURE_RELEASE/deepwind-harness-claude-v1.2.3.tar.gz")
  codex_sha=$(test_sha256 "$FIXTURE_RELEASE/deepwind-harness-codex-v1.2.3.tar.gz")
  claude_bytes=$(wc -c < "$FIXTURE_RELEASE/deepwind-harness-claude-v1.2.3.tar.gz" | tr -d '[:space:]')
  codex_bytes=$(wc -c < "$FIXTURE_RELEASE/deepwind-harness-codex-v1.2.3.tar.gz" | tr -d '[:space:]')
  claude_files=$(tar -tzf "$FIXTURE_RELEASE/deepwind-harness-claude-v1.2.3.tar.gz" \
    | sed -e 's#^\./##' | jq -Rsc 'split("\n") | map(select(length > 0))')
  codex_files=$(tar -tzf "$FIXTURE_RELEASE/deepwind-harness-codex-v1.2.3.tar.gz" \
    | sed -e 's#^\./##' | jq -Rsc 'split("\n") | map(select(length > 0))')
  bootstrap_sha=$(test_sha256 "$FIXTURE_INSTALLER")
  bootstrap_bytes=$(wc -c < "$FIXTURE_INSTALLER" | tr -d '[:space:]')

  jq -nS \
    --arg claude_sha "$claude_sha" --arg codex_sha "$codex_sha" --arg bootstrap_sha "$bootstrap_sha" \
    --argjson claude_bytes "$claude_bytes" --argjson codex_bytes "$codex_bytes" --argjson bootstrap_bytes "$bootstrap_bytes" \
    --argjson claude_files "$claude_files" --argjson codex_files "$codex_files" \
    '{
      formatVersion: 1,
      version: "1.2.3",
      tag: "v1.2.3",
      channel: "staging",
      endpoint: {alias: "deepwind", url: "https://app.deepwind.ai/mcp"},
      signing: {
        keyId: "fixture-key",
        notBefore: "2026-01-01T00:00:00Z",
        notAfter: "2027-01-01T00:00:00Z",
        signatureFile: "deepwind-release-manifest.json.asc"
      },
      provenance: {repository: "DeepWindAI/harness", revision: "deadbeef"},
      bootstrap: {
        file: "deepwind-init-v1.2.3.sh",
        sha256: $bootstrap_sha,
        bytes: $bootstrap_bytes
      },
      archives: [
        {
          target: "claude",
          file: "deepwind-harness-claude-v1.2.3.tar.gz",
          sha256: $claude_sha,
          bytes: $claude_bytes,
          files: $claude_files
        },
        {
          target: "codex",
          file: "deepwind-harness-codex-v1.2.3.tar.gz",
          sha256: $codex_sha,
          bytes: $codex_bytes,
          files: $codex_files
        }
      ]
    }' > "$FIXTURE_RELEASE/deepwind-release-manifest.json"
  printf 'TEST-SIGNATURE\n' > "$FIXTURE_RELEASE/deepwind-release-manifest.json.asc"
}

refresh_codex_fixture_archive() {
  codex_archive="$FIXTURE_RELEASE/deepwind-harness-codex-v1.2.3.tar.gz"
  tar -C "$FIXTURE_RELEASE/codex" -czf "$codex_archive" .agents plugins codex
  codex_sha=$(test_sha256 "$codex_archive")
  codex_bytes=$(wc -c < "$codex_archive" | tr -d '[:space:]')
  codex_files=$(tar -tzf "$codex_archive" \
    | sed -e 's#^\./##' | jq -Rsc 'split("\n") | map(select(length > 0))')
  jq \
    --arg codex_sha "$codex_sha" \
    --argjson codex_bytes "$codex_bytes" \
    --argjson codex_files "$codex_files" \
    '(.archives[] | select(.target == "codex")) |=
      (.sha256 = $codex_sha | .bytes = $codex_bytes | .files = $codex_files)' \
    "$FIXTURE_RELEASE/deepwind-release-manifest.json" \
    > "$FIXTURE_RELEASE/deepwind-release-manifest.json.next"
  mv "$FIXTURE_RELEASE/deepwind-release-manifest.json.next" \
    "$FIXTURE_RELEASE/deepwind-release-manifest.json"
}

run_fixture_installer() {
  env \
    HOME="$FIXTURE_HOME" \
    TMPDIR="$FIXTURE_HOME/tmp" \
    PATH="$FIXTURE_ROOT/bin:$PATH" \
    DEEPWIND_INSTALL_TESTING=1 \
    DEEPWIND_RELEASE_DIR="$FIXTURE_RELEASE" \
    bash "$FIXTURE_INSTALLER" --version 1.2.3 "$@"
}

write_fixture_codex_lifecycle_stub() {
  cat > "$FIXTURE_ROOT/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${HOME:?}"
printf '%s\n' "$*" >> "$HOME/codex-plugin-calls"
marketplace_state="$HOME/.fixture-codex-marketplace"
plugin_state="$HOME/.fixture-codex-plugin"

case "$*" in
  "plugin marketplace list --json")
    if [ -f "$marketplace_state" ]; then
      jq -n --arg source "$(cat "$marketplace_state")" \
        '{marketplaces:[{name:"deepwind",root:$source,marketplaceSource:{sourceType:"local",source:$source}}]}'
    else
      printf '%s\n' '{"marketplaces":[]}'
    fi
    ;;
  "plugin marketplace add "*" --json")
    source_path=${4}
    printf '%s' "$source_path" > "$marketplace_state"
    jq -n --arg source "$source_path" \
      '{marketplaceName:"deepwind",installedRoot:$source,alreadyAdded:false}'
    ;;
  "plugin add deepwind-harness@deepwind --json")
    [ -f "$marketplace_state" ]
    : > "$plugin_state"
    printf '%s\n' '{"pluginId":"deepwind-harness@deepwind","version":"1.2.3"}'
    ;;
  "plugin list --json")
    if [ -f "$plugin_state" ]; then
      source_path=$(cat "$marketplace_state")
      jq -n --arg source "$source_path" \
        '{installed:[{pluginId:"deepwind-harness@deepwind",version:"1.2.3",installed:true,enabled:true,marketplaceSource:{sourceType:"local",source:$source}}],available:[]}'
    else
      printf '%s\n' '{"installed":[],"available":[]}'
    fi
    ;;
  *)
    printf 'unexpected Codex fixture invocation: %s\n' "$*" >&2
    exit 64
    ;;
esac
EOF
  chmod 755 "$FIXTURE_ROOT/bin/codex"
}

write_fixture_node_stub() {
  fixture_node_major=${1:-22}
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -eu' \
    ': "${HOME:?}"' \
    'printf "%s\n" "$*" >> "$HOME/node-calls"' \
    "printf '%s\\n' '$fixture_node_major'" \
    > "$FIXTURE_ROOT/bin/node"
  chmod 755 "$FIXTURE_ROOT/bin/node"
}

write_fixture_npm_stub() {
  fixture_npm_outcome=${1:-success}
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -eu' \
    ': "${HOME:?}"' \
    'printf "%s\n" "$*" >> "$HOME/npm-calls"' \
    > "$FIXTURE_ROOT/bin/npm"
  if [ "$fixture_npm_outcome" = success ]; then
    printf '%s\n' 'exit 0' >> "$FIXTURE_ROOT/bin/npm"
  else
    printf '%s\n' 'exit 1' >> "$FIXTURE_ROOT/bin/npm"
  fi
  chmod 755 "$FIXTURE_ROOT/bin/npm"
}

write_fixture_timeout_stub() {
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -eu' \
    ': "${HOME:?}"' \
    'printf "%s\n" "$*" >> "$HOME/timeout-calls"' \
    'fixture_timeout_seconds=$1' \
    'shift' \
    'exec "$@"' \
    > "$FIXTURE_ROOT/bin/timeout"
  chmod 755 "$FIXTURE_ROOT/bin/timeout"
}

# Build a directory containing only the external tools the standalone
# installer requires (release/build-installer.sh's need_command list),
# resolved from whatever is actually on the host's PATH, but deliberately
# excluding any binary named `timeout` or `gtimeout`. This lets a test force
# the "no timeout binary available" fallback deterministically, regardless of
# whether the host running the suite has GNU coreutils `timeout` (common on
# Linux) or Homebrew's `gtimeout` (common on macOS with coreutils installed)
# on its real PATH.
write_fixture_toolchain_without_timeout() {
  FIXTURE_TOOLCHAIN="$FIXTURE_ROOT/toolchain-no-timeout"
  mkdir -p "$FIXTURE_TOOLCHAIN"
  for fixture_toolchain_tool in \
    bash id realpath stat mktemp jq tar awk sed grep \
    cp mv chmod mkdir rmdir rm find df sort base64 date tr wc; do
    fixture_toolchain_resolved=$(command -v "$fixture_toolchain_tool") || {
      printf 'fixture setup: %s is required but not on PATH\n' "$fixture_toolchain_tool" >&2
      return 1
    }
    ln -s "$fixture_toolchain_resolved" "$FIXTURE_TOOLCHAIN/$fixture_toolchain_tool"
  done
  if fixture_toolchain_resolved=$(command -v sha256sum 2>/dev/null); then
    ln -s "$fixture_toolchain_resolved" "$FIXTURE_TOOLCHAIN/sha256sum"
  else
    fixture_toolchain_resolved=$(command -v shasum) || {
      printf 'fixture setup: sha256sum/shasum is required but not on PATH\n' >&2
      return 1
    }
    ln -s "$fixture_toolchain_resolved" "$FIXTURE_TOOLCHAIN/shasum"
  fi
}

# Like run_fixture_installer, but PATH is fully replaced (no fallback to the
# host's real PATH) by $FIXTURE_ROOT/bin plus a curated toolchain directory
# that never contains `timeout`/`gtimeout`. Use this to assert best-effort
# post-commit network steps still run and still succeed/warn as before when
# no timeout binary exists anywhere on PATH.
run_fixture_installer_without_timeout() {
  write_fixture_toolchain_without_timeout
  env \
    HOME="$FIXTURE_HOME" \
    TMPDIR="$FIXTURE_HOME/tmp" \
    PATH="$FIXTURE_ROOT/bin:$FIXTURE_TOOLCHAIN" \
    DEEPWIND_INSTALL_TESTING=1 \
    DEEPWIND_RELEASE_DIR="$FIXTURE_RELEASE" \
    bash "$FIXTURE_INSTALLER" --version 1.2.3 "$@"
}

refresh_claude_fixture_archive() {
  claude_archive="$FIXTURE_RELEASE/deepwind-harness-claude-v1.2.3.tar.gz"
  tar -C "$FIXTURE_RELEASE/claude" -czf "$claude_archive" agents skills
  claude_sha=$(test_sha256 "$claude_archive")
  claude_bytes=$(wc -c < "$claude_archive" | tr -d '[:space:]')
  claude_files=$(tar -tzf "$claude_archive" \
    | sed -e 's#^\./##' | jq -Rsc 'split("\n") | map(select(length > 0))')
  jq \
    --arg claude_sha "$claude_sha" \
    --argjson claude_bytes "$claude_bytes" \
    --argjson claude_files "$claude_files" \
    '(.archives[] | select(.target == "claude")) |=
      (.sha256 = $claude_sha | .bytes = $claude_bytes | .files = $claude_files)' \
    "$FIXTURE_RELEASE/deepwind-release-manifest.json" \
    > "$FIXTURE_RELEASE/deepwind-release-manifest.json.next"
  mv "$FIXTURE_RELEASE/deepwind-release-manifest.json.next" \
    "$FIXTURE_RELEASE/deepwind-release-manifest.json"
}

remove_fixture_release() {
  [ -n "${FIXTURE_ROOT:-}" ] && rm -rf "$FIXTURE_ROOT"
}
