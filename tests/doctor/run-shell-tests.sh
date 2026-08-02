#!/usr/bin/env bash
# The fake Codex executable is assembled from literal shell source lines.
# shellcheck disable=SC2016
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/deepwind-doctor-test.XXXXXX")
trap 'find "$TMP" -depth -type f -exec rm -f {} \;; find "$TMP" -depth -type d -exec rmdir {} \; 2>/dev/null || true' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -f "$ROOT/lib/codex-mcp.sh" ] || fail 'lib/codex-mcp.sh is missing'
[ -f "$ROOT/lib/doctor.sh" ] || fail 'lib/doctor.sh is missing'
# shellcheck source=lib/codex-mcp.sh
. "$ROOT/lib/codex-mcp.sh"
# shellcheck source=lib/doctor.sh
. "$ROOT/lib/doctor.sh"

mkdir -p "$TMP/bin" "$TMP/empty-bin"
CODEX_CALL_LOG="$TMP/codex-calls.log"
export CODEX_CALL_LOG
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$*" >> "$CODEX_CALL_LOG"' \
  'case "$*" in' \
  '  "mcp add deepwind --url https://app.deepwind.ai/mcp")' \
  '    printf "%s\n" "${FAKE_CODEX_ADD_TEXT:-added token=ADD-SECRET}"' \
  '    exit "${FAKE_CODEX_ADD_EXIT:-0}" ;;' \
  '  "mcp login deepwind")' \
  '    printf "%s\n" "${FAKE_CODEX_LOGIN_TEXT:-oauth token=LOGIN-SECRET}" >&2' \
  '    exit "${FAKE_CODEX_LOGIN_EXIT:-0}" ;;' \
  '  "mcp get deepwind")' \
  '    printf "%s\n" "${FAKE_CODEX_TRANSCRIPT:-enabled streamable_http https://app.deepwind.ai/mcp}"' \
  '    exit "${FAKE_CODEX_GET_EXIT:-0}" ;;' \
  '  *) printf "unexpected argv\n" >&2; exit 91 ;;' \
  'esac' > "$TMP/bin/codex"
chmod 755 "$TMP/bin/codex"

MANIFEST_FILE="$TMP/manifest.json"
export MANIFEST_FILE
printf '%s\n' \
  '{"channel":"staging","endpoint":{"alias":"deepwind","url":"https://app.deepwind.ai/mcp"}}' \
  > "$MANIFEST_FILE"

: > "$CODEX_CALL_LOG"
if (
  interactive_tty() { return 1; }
  PATH="$TMP/bin:$PATH" configure_codex_mcp staging yes
) > "$TMP/no-tty.out" 2>&1; then
  fail 'configure_codex_mcp succeeded without an interactive TTY'
fi
[ ! -s "$CODEX_CALL_LOG" ] || fail 'Codex was invoked without an interactive TTY'

: > "$CODEX_CALL_LOG"
if (
  interactive_tty() { return 0; }
  PATH="$TMP/bin:$PATH" configure_codex_mcp staging no
) > "$TMP/no-consent.out" 2>&1; then
  fail 'configure_codex_mcp succeeded without exact consent'
fi
[ ! -s "$CODEX_CALL_LOG" ] || fail 'Codex was invoked without exact consent'

: > "$CODEX_CALL_LOG"
if (
  interactive_tty() { return 0; }
  PATH="$TMP/empty-bin" configure_codex_mcp staging yes
) > "$TMP/no-cli.out" 2>&1; then
  fail 'configure_codex_mcp succeeded without the Codex CLI'
fi
[ ! -s "$CODEX_CALL_LOG" ] || fail 'an unavailable Codex CLI somehow mutated configuration'

: > "$CODEX_CALL_LOG"
(
  interactive_tty() { return 0; }
  PATH="$TMP/bin:$PATH" configure_codex_mcp staging yes
) > "$TMP/configured.out" 2>&1 || fail 'explicit staging configuration failed'
[ "$(sed -n '1p' "$CODEX_CALL_LOG")" = 'mcp add deepwind --url https://app.deepwind.ai/mcp' ] \
  || fail 'Codex add argv was not fixed to the allowlisted staging endpoint'
[ "$(sed -n '2p' "$CODEX_CALL_LOG")" = 'mcp login deepwind' ] \
  || fail 'Codex login argv was not fixed to the staging alias'
[ "$(wc -l < "$CODEX_CALL_LOG" | tr -d '[:space:]')" -eq 2 ] \
  || fail 'configuration made unexpected Codex calls'
if rg -q 'ADD-SECRET|LOGIN-SECRET|token=' "$TMP/configured.out"; then
  fail 'Codex output leaked from successful configuration'
fi

: > "$CODEX_CALL_LOG"
if (
  interactive_tty() { return 0; }
  FAKE_CODEX_LOGIN_EXIT=17 \
    PATH="$TMP/bin:$PATH" configure_codex_mcp staging yes
) > "$TMP/login-failure.out" 2>&1; then
  fail 'login failure was reported as configured'
fi
if rg -q 'LOGIN-SECRET|token=|workspace' "$TMP/login-failure.out"; then
  fail 'login failure output was not redacted'
fi

printf '%s\n' \
  '{"channel":"staging","endpoint":{"alias":"deepwind","url":"https://attacker.example/mcp"}}' \
  > "$MANIFEST_FILE"
: > "$CODEX_CALL_LOG"
if (
  interactive_tty() { return 0; }
  PATH="$TMP/bin:$PATH" configure_codex_mcp staging yes
) > "$TMP/bad-endpoint.out" 2>&1; then
  fail 'a non-allowlisted endpoint was accepted'
fi
[ ! -s "$CODEX_CALL_LOG" ] || fail 'Codex was invoked for a non-allowlisted endpoint'
printf '%s\n' \
  '{"channel":"staging","endpoint":{"alias":"deepwind","url":"https://app.deepwind.ai/mcp"}}' \
  > "$MANIFEST_FILE"

: > "$CODEX_CALL_LOG"
FAKE_CODEX_TRANSCRIPT='No DeepWind workspace is configured for SecretCorp; token=WORKSPACE-SECRET' \
  PATH="$TMP/bin:$PATH" doctor codex > "$TMP/no-workspace.out" 2>&1
rg -q '"status":"no-workspace"' "$TMP/no-workspace.out" \
  || fail 'doctor did not classify the no-workspace state'
if rg -q 'SecretCorp|WORKSPACE-SECRET|token=' "$TMP/no-workspace.out"; then
  fail 'doctor leaked workspace or transcript data'
fi
[ "$(cat "$CODEX_CALL_LOG")" = 'mcp get deepwind' ] \
  || fail 'doctor made more than one or a non-status Codex call'

: > "$CODEX_CALL_LOG"
FAKE_CODEX_TRANSCRIPT='OAuth login required for alice@example.test token=OAUTH-SECRET' \
  PATH="$TMP/bin:$PATH" doctor both > "$TMP/oauth.out" 2>&1
rg -q '"status":"oauth-required"' "$TMP/oauth.out" \
  || fail 'doctor did not classify OAuth-required state'
if rg -q 'alice@example.test|OAUTH-SECRET|token=' "$TMP/oauth.out"; then
  fail 'doctor leaked OAuth transcript data'
fi

: > "$CODEX_CALL_LOG"
FAKE_CODEX_TRANSCRIPT='Session not found while connecting to remote server' \
  PATH="$TMP/bin:$PATH" doctor codex > "$TMP/connection.out" 2>&1
rg -q '"status":"connection-unavailable"' "$TMP/connection.out" \
  || fail 'doctor did not classify connection failure'

PATH="$TMP/empty-bin" doctor codex > "$TMP/cli-unavailable.out" 2>&1
rg -q '"status":"cli-unavailable"' "$TMP/cli-unavailable.out" \
  || fail 'doctor did not classify unavailable Codex CLI'

if rg -q -e '(^|[[:space:]])(query|create|update|login|add)([[:space:]]|$)' "$CODEX_CALL_LOG"; then
  fail 'doctor invoked a mutating or DeepWind data command'
fi

jq -e '
  .formatVersion == 1 and
  .channel == "staging" and
  .displayName == "DeepWind" and
  .endpoint.alias == "deepwind" and
  .endpoint.url == "https://app.deepwind.ai/mcp" and
  .endpoint.transport == "streamable-http" and
  .endpoint.oauth == "interactive"
' "$ROOT/config/channels/staging.json" >/dev/null \
  || fail 'staging channel configuration is missing or unsafe'

if rg -q 'https://mcp[.]deepwind[.]ai/v1/sse' \
  "$ROOT/config" "$ROOT/lib" "$ROOT/payload/mcp"; then
  fail 'legacy SSE endpoint remains in emitted staging assets'
fi

rg -q -- '--configure-mcp' "$ROOT/lib/args.sh" \
  || fail 'installer argument parser does not expose explicit MCP configuration'
rg -q 'codex-mcp doctor' "$ROOT/release/build-installer.sh" \
  || fail 'standalone installer does not include the MCP security units'
rg -q 'maybe_configure_codex_mcp' "$ROOT/release/build-installer.sh" \
  || fail 'standalone installer does not gate MCP onboarding after file install'
rg -q 'CHANNEL_CONFIG=config/channels/staging.json' \
  "$ROOT/.github/workflows/weekly-release.yml" \
  || fail 'release workflow does not source the reviewed staging channel'

# Verify the generated curl-pipe installer keeps file installation independent
# from the optional MCP action.
# shellcheck source=tests/installer/helpers.bash
. "$ROOT/tests/installer/helpers.bash"
make_fixture_release
cp "$TMP/bin/codex" "$FIXTURE_ROOT/bin/codex"
: > "$CODEX_CALL_LOG"
run_fixture_installer > "$TMP/default-install.out" 2>&1 \
  || fail 'default dual-target fixture install failed'
[ ! -s "$CODEX_CALL_LOG" ] \
  || fail 'default dual-target install invoked Codex'
[ -f "$FIXTURE_HOME/.codex/agents/harness-coordinator.toml" ] \
  || fail 'default dual-target install did not install Codex files'
remove_fixture_release

make_fixture_release
cp "$TMP/bin/codex" "$FIXTURE_ROOT/bin/codex"
: > "$CODEX_CALL_LOG"
run_fixture_installer --configure-mcp > "$TMP/non-tty-install.out" 2>&1 \
  || fail 'non-TTY MCP onboarding blocked installed harness files'
if rg -q -e '(^|[[:space:]])(add|login)([[:space:]]|$)' "$CODEX_CALL_LOG"; then
  fail 'non-TTY MCP onboarding invoked a configuration command'
fi
[ -f "$FIXTURE_HOME/.codex/agents/harness-coordinator.toml" ] \
  || fail 'non-TTY MCP onboarding rolled back installed harness files'
remove_fixture_release

printf 'PASS: MCP onboarding and doctor security tests\n'
