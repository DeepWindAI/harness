# shellcheck shell=bash
# Explicit, user-mediated Codex MCP onboarding. This unit never reads or writes
# OAuth token storage and never accepts an endpoint from an unsigned source.

DEEPWIND_STAGING_CHANNEL=staging
DEEPWIND_STAGING_ALIAS=deepwind
DEEPWIND_STAGING_URL=https://app.deepwind.ai/mcp

_mcp_info() {
  printf '%s\n' "$*"
}

_mcp_warn() {
  printf 'warning: %s\n' "$*" >&2
}

interactive_tty() {
  [ -c /dev/tty ] || return 1
  (: 2>/dev/null </dev/tty >/dev/tty)
}

verified_staging_endpoint() {
  endpoint_channel=$1
  [ "$endpoint_channel" = "$DEEPWIND_STAGING_CHANNEL" ] || return 1
  [ -n "${MANIFEST_FILE:-}" ] && [ -f "$MANIFEST_FILE" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  endpoint_fields=$(jq -er '
    [.channel, .endpoint.alias, .endpoint.url]
    | select(all(.[]; type == "string"))
    | @tsv
  ' "$MANIFEST_FILE" 2>/dev/null) || return 1
  IFS='	' read -r endpoint_manifest_channel endpoint_alias endpoint_url \
    <<< "$endpoint_fields"

  [ "$endpoint_manifest_channel" = "$DEEPWIND_STAGING_CHANNEL" ] \
    && [ "$endpoint_alias" = "$DEEPWIND_STAGING_ALIAS" ] \
    && [ "$endpoint_url" = "$DEEPWIND_STAGING_URL" ]
}

configure_codex_mcp() {
  configure_channel=$1
  configure_consent=$2

  if ! interactive_tty; then
    _mcp_warn 'DeepWind MCP configuration skipped: an interactive terminal is required.'
    return 3
  fi
  if [ "$configure_consent" != yes ]; then
    _mcp_warn 'DeepWind MCP configuration skipped: explicit confirmation was not provided.'
    return 3
  fi
  if ! command -v codex >/dev/null 2>&1; then
    _mcp_warn 'DeepWind MCP configuration skipped: Codex CLI is unavailable.'
    return 4
  fi
  if ! verified_staging_endpoint "$configure_channel"; then
    _mcp_warn 'DeepWind MCP configuration refused: the signed staging endpoint is not allowlisted.'
    return 5
  fi

  _mcp_info 'Configuring DeepWind for the interactive Codex coordinator.'
  if ! run_with_net_timeout codex mcp add "$DEEPWIND_STAGING_ALIAS" \
    --url "$DEEPWIND_STAGING_URL" >/dev/null 2>&1; then
    _mcp_warn 'Codex could not register the DeepWind staging connector (or timed out); installed files are unchanged.'
    return 6
  fi
  if ! run_with_net_timeout codex mcp login "$DEEPWIND_STAGING_ALIAS" >/dev/null 2>&1; then
    _mcp_warn 'DeepWind OAuth did not complete (or timed out); rerun with --configure-mcp when ready.'
    return 7
  fi
  _mcp_info 'DeepWind MCP is registered for this interactive Codex user.'
}

maybe_configure_codex_mcp() {
  onboarding_channel=$1
  if ! interactive_tty; then
    configure_codex_mcp "$onboarding_channel" no
    return $?
  fi

  printf '%s\n' \
    'DeepWind MCP channel: staging' \
    'Endpoint: https://app.deepwind.ai/mcp' \
    'OAuth is stored and managed by Codex for this interactive user only.' \
    > /dev/tty
  printf 'Type yes to register and authenticate DeepWind: ' > /dev/tty
  onboarding_consent=
  IFS= read -r onboarding_consent < /dev/tty || onboarding_consent=
  configure_codex_mcp "$onboarding_channel" "$onboarding_consent"
}
