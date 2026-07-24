# shellcheck shell=bash disable=SC2034
# Opt-in lifecycle for the verified, release-contained Codex plugin.
#
# Only the Codex CLI owns Codex configuration and cache mutations. This unit
# never edits config.toml or a personal marketplace catalog directly, and it
# refuses to replace a configured marketplace that points anywhere except the
# verified installer-managed release root.

DEEPWIND_CODEX_PLUGIN_ID=deepwind-harness@deepwind
DEEPWIND_CODEX_MARKETPLACE=deepwind

inspect_codex_plugin() {
  CODEX_PLUGIN_STATUS=cli-unavailable
  command -v codex >/dev/null 2>&1 || return 0

  marketplace_json="$WORK_DIR/codex-marketplaces.json"
  if ! codex plugin marketplace list --json > "$marketplace_json" 2>/dev/null; then
    CODEX_PLUGIN_STATUS=command-error
    return 0
  fi
  if ! jq -e '.marketplaces | type == "array"' "$marketplace_json" >/dev/null 2>&1; then
    CODEX_PLUGIN_STATUS=command-error
    return 0
  fi

  marketplace_count=$(jq -r --arg name "$DEEPWIND_CODEX_MARKETPLACE" \
    '[.marketplaces[] | select(.name == $name)] | length' "$marketplace_json")
  if [ "$marketplace_count" -eq 0 ]; then
    CODEX_PLUGIN_STATUS=marketplace-not-configured
    return 0
  fi
  if [ "$marketplace_count" -ne 1 ] || ! jq -e \
    --arg name "$DEEPWIND_CODEX_MARKETPLACE" \
    --arg source "$CODEX_MARKETPLACE_DIR" '
      any(.marketplaces[];
        .name == $name and
        .marketplaceSource.sourceType == "local" and
        .marketplaceSource.source == $source and
        .root == $source
      )
    ' "$marketplace_json" >/dev/null; then
    CODEX_PLUGIN_STATUS=marketplace-conflict
    return 0
  fi

  plugin_json="$WORK_DIR/codex-plugins.json"
  if ! codex plugin list --json > "$plugin_json" 2>/dev/null; then
    CODEX_PLUGIN_STATUS=command-error
    return 0
  fi
  if ! jq -e '.installed | type == "array"' "$plugin_json" >/dev/null 2>&1; then
    CODEX_PLUGIN_STATUS=command-error
    return 0
  fi

  plugin_count=$(jq -r --arg id "$DEEPWIND_CODEX_PLUGIN_ID" \
    '[.installed[] | select(.pluginId == $id)] | length' "$plugin_json")
  if [ "$plugin_count" -eq 0 ]; then
    CODEX_PLUGIN_STATUS=plugin-not-enabled
    return 0
  fi
  if [ "$plugin_count" -ne 1 ] || ! jq -e \
    --arg id "$DEEPWIND_CODEX_PLUGIN_ID" \
    --arg source "$CODEX_MARKETPLACE_DIR" '
      any(.installed[];
        .pluginId == $id and
        .marketplaceSource.sourceType == "local" and
        .marketplaceSource.source == $source
      )
    ' "$plugin_json" >/dev/null; then
    CODEX_PLUGIN_STATUS=plugin-source-conflict
    return 0
  fi
  if ! jq -e --arg id "$DEEPWIND_CODEX_PLUGIN_ID" \
    'any(.installed[]; .pluginId == $id and .installed == true and .enabled == true)' \
    "$plugin_json" >/dev/null; then
    CODEX_PLUGIN_STATUS=plugin-disabled
    return 0
  fi
  if ! jq -e --arg id "$DEEPWIND_CODEX_PLUGIN_ID" --arg version "$VERSION" \
    'any(.installed[]; .pluginId == $id and .version == $version)' \
    "$plugin_json" >/dev/null; then
    CODEX_PLUGIN_STATUS=plugin-outdated
    return 0
  fi

  CODEX_PLUGIN_STATUS=enabled
}

print_codex_plugin_status() {
  inspect_codex_plugin
  case "$CODEX_PLUGIN_STATUS" in
    enabled)
      printf 'plugin: enabled (%s %s)\n' "$DEEPWIND_CODEX_PLUGIN_ID" "$VERSION"
      ;;
    cli-unavailable)
      printf '%s\n' \
        'plugin: cli-unavailable (install Codex CLI, then rerun with --enable-codex-plugin)'
      ;;
    marketplace-not-configured|plugin-not-enabled|plugin-disabled)
      printf 'plugin: not-enabled (%s; rerun with --enable-codex-plugin)\n' \
        "$CODEX_PLUGIN_STATUS"
      ;;
    plugin-outdated)
      printf '%s\n' \
        'plugin: outdated (rerun this release with --enable-codex-plugin)'
      return 1
      ;;
    marketplace-conflict)
      printf '%s\n' \
        'plugin: conflict (configured DeepWind marketplace points outside the verified release)'
      return 1
      ;;
    plugin-source-conflict)
      printf '%s\n' \
        'plugin: conflict (installed DeepWind plugin has an unexpected marketplace source)'
      return 1
      ;;
    *)
      printf '%s\n' \
        'plugin: unavailable (Codex lifecycle command failed; rerun --check after repairing Codex CLI)'
      ;;
  esac
  return 0
}

preflight_codex_plugin_enablement() {
  inspect_codex_plugin
  case "$CODEX_PLUGIN_STATUS" in
    enabled|marketplace-not-configured|plugin-not-enabled|plugin-disabled|plugin-outdated)
      return 0
      ;;
    marketplace-conflict)
      die "configured DeepWind marketplace points outside the verified release; preserving it unchanged"
      ;;
    plugin-source-conflict)
      die "installed DeepWind plugin has an unexpected marketplace source; preserving it unchanged"
      ;;
    cli-unavailable)
      die "Codex CLI is required by --enable-codex-plugin"
      ;;
    *)
      die "Codex plugin state could not be inspected; no install or plugin lifecycle change was attempted"
      ;;
  esac
}

enable_codex_plugin() {
  inspect_codex_plugin
  marketplace_added=0
  case "$CODEX_PLUGIN_STATUS" in
    enabled)
      info "Codex plugin already enabled: $DEEPWIND_CODEX_PLUGIN_ID $VERSION"
      return 0
      ;;
    marketplace-conflict)
      die "configured DeepWind marketplace changed during installation; preserving it unchanged"
      ;;
    plugin-source-conflict)
      die "installed DeepWind plugin has an unexpected marketplace source; preserving it unchanged"
      ;;
    cli-unavailable)
      die "Codex CLI is required by --enable-codex-plugin"
      ;;
    command-error)
      die "Codex plugin state changed or became unavailable during installation"
      ;;
    marketplace-not-configured)
      if ! codex plugin marketplace add "$CODEX_MARKETPLACE_DIR" --json >/dev/null 2>&1; then
        die "Codex could not configure the verified DeepWind marketplace"
      fi
      marketplace_added=1
      ;;
    plugin-not-enabled|plugin-disabled|plugin-outdated)
      ;;
    *)
      die "unexpected Codex plugin state: $CODEX_PLUGIN_STATUS"
      ;;
  esac

  if ! codex plugin add deepwind-harness@deepwind --json >/dev/null 2>&1; then
    if [ "$marketplace_added" -eq 1 ]; then
      codex plugin marketplace remove deepwind --json >/dev/null 2>&1 || true
    fi
    die "Codex could not enable the verified DeepWind plugin"
  fi

  inspect_codex_plugin
  [ "$CODEX_PLUGIN_STATUS" = enabled ] \
    || die "Codex did not report the verified DeepWind plugin as enabled"
  info "Codex plugin enabled: $DEEPWIND_CODEX_PLUGIN_ID $VERSION"
}
