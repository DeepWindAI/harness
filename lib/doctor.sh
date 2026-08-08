# shellcheck shell=bash disable=SC2154
# Privacy-safe, non-mutating MCP diagnostics. Raw Codex output is consumed by a
# fixed classifier and is never emitted, retained, or written to a log.

classify_codex_mcp_stream() {
  awk '
    BEGIN { exit_status = 0 }
    /^__DEEPWIND_CODEX_EXIT=[0-9]+$/ {
      sub(/^__DEEPWIND_CODEX_EXIT=/, "")
      exit_status = $0 + 0
      next
    }
    {
      line = tolower($0)
      if (line ~ /no[^[:alnum:]]+(deepwind[^[:alnum:]]+)?workspace|workspace[^[:alnum:]]+(is[[:space:]]+)?not[[:space:]-]*configured/) no_workspace = 1
      if (line ~ /oauth|unauthori[sz]ed|authentication|login[[:space:]-]+required|not[[:space:]-]+logged/) oauth = 1
      if (line ~ /session[[:space:]-]+not[[:space:]-]+found|connection|connect[[:space:]-]+failed|unavailable|timed?[[:space:]-]*out|network[[:space:]-]+error/) connection = 1
      if (line ~ /server[[:space:]-]+not[[:space:]-]+found|unknown[[:space:]-]+server|mcp[^[:alnum:]]+not[[:space:]-]+configured/) not_configured = 1
      if (line ~ /enabled|streamable[_ -]?http|https:\/\/dev[.]deepwind[.]ai\/mcp/) configured = 1
    }
    END {
      if (no_workspace) print "no-workspace"
      else if (oauth) print "oauth-required"
      else if (connection) print "connection-unavailable"
      else if (not_configured) print "not-configured"
      else if (configured) print "configured"
      else if (exit_status != 0) print "command-error"
      else print "configured"
    }
  '
}

codex_mcp_status() {
  if ! command -v codex >/dev/null 2>&1; then
    printf '%s\n' cli-unavailable
    return 0
  fi

  {
    codex_status=0
    codex mcp get "$DEEPWIND_STAGING_ALIAS" 2>&1 || codex_status=$?
    printf '__DEEPWIND_CODEX_EXIT=%s\n' "$codex_status"
  } | classify_codex_mcp_stream
}

# Local-only bridge CLI diagnostics, symmetric with codex_mcp_status above:
# no network calls, no mutation. Sets BRIDGE_STATUS (installed|not-installed),
# BRIDGE_VERSION (empty when unknown), and BRIDGE_REGISTERED (true|false) for
# doctor() to report. "Registered" means a local token was persisted by
# `pm33-bridge login`/`register`, not that a live connection exists — doctor
# cannot verify that without a network round trip, so it never reports
# "connected".
bridge_cli_status() {
  BRIDGE_STATUS=not-installed
  BRIDGE_VERSION=
  BRIDGE_REGISTERED=false

  # Probe ONLY the unambiguous `pm33-bridge` bin, never the generic `bridge`:
  # @deepwind/bridge installs both, but `bridge` collides with iproute2's
  # /usr/sbin/bridge on Linux, which would make doctor falsely report the
  # DeepWind bridge as installed. pm33-bridge is present whenever our bridge is.
  bridge_bin=
  if command -v pm33-bridge >/dev/null 2>&1; then
    bridge_bin=pm33-bridge
  fi

  if [ -n "$bridge_bin" ]; then
    BRIDGE_STATUS=installed
    BRIDGE_VERSION=$("$bridge_bin" --version 2>/dev/null | awk 'NR == 1' | tr -d '[:space:]')
    case "$BRIDGE_VERSION" in
      ''|*[!A-Za-z0-9._+-]*) BRIDGE_VERSION= ;;
    esac
  fi

  # ~/.pm33/bridge.json is the bridge CLI's own persisted config (its
  # config.js reads apiUrl/apiToken/workspaceDir from this exact path).
  # A non-empty apiToken means `login`/`register` completed at some point;
  # it says nothing about whether that token is still valid.
  bridge_config="${HOME:-}/.pm33/bridge.json"
  if [ -n "${HOME:-}" ] && [ -f "$bridge_config" ] && [ ! -L "$bridge_config" ] \
    && command -v jq >/dev/null 2>&1 \
    && jq -e '(.apiToken // "") | length > 0' "$bridge_config" >/dev/null 2>&1; then
    BRIDGE_REGISTERED=true
  fi
  return 0
}

doctor() {
  doctor_target=$1
  case "$doctor_target" in
    claude)
      printf '%s\n' '{"target":"claude","component":"mcp","status":"not-applicable"}'
      ;;
    codex|both)
      doctor_status=$(codex_mcp_status)
      printf '{"target":"codex","component":"mcp","channel":"staging","status":"%s"}\n' \
        "$doctor_status"
      ;;
    *)
      printf '%s\n' '{"target":"unknown","component":"mcp","status":"not-applicable"}'
      ;;
  esac
  if command -v recovery_state_summary >/dev/null 2>&1 \
    && [ -n "${RECOVERY_STATE_FILE:-}" ]; then
    if recovery_state_summary; then
      printf '{"target":"installer","component":"recovery","status":"%s","count":%s}\n' \
        "$RECOVERY_STATUS" "$RECOVERY_COUNT"
    else
      printf '%s\n' \
        '{"target":"installer","component":"recovery","status":"attention-required","count":0}'
    fi
  else
    printf '%s\n' \
      '{"target":"installer","component":"recovery","status":"unavailable","count":0}'
  fi
  bridge_cli_status
  if [ -n "$BRIDGE_VERSION" ]; then
    printf '{"target":"installer","component":"bridge","status":"%s","version":"%s","registered":%s}\n' \
      "$BRIDGE_STATUS" "$BRIDGE_VERSION" "$BRIDGE_REGISTERED"
  else
    printf '{"target":"installer","component":"bridge","status":"%s","registered":%s}\n' \
      "$BRIDGE_STATUS" "$BRIDGE_REGISTERED"
  fi
  return 0
}
