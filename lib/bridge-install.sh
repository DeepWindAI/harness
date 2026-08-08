# shellcheck shell=bash disable=SC2034
# Opt-in, best-effort installation of the DeepWind bridge CLI via npm.
#
# This unit runs only after apply_transaction has committed the signed,
# journaled release install (TRANSACTION_COMMITTED=1). `npm i -g` is a live
# network call outside that trust boundary: it cannot be journaled, verified
# against the release manifest, or rolled back. Every failure path here warns
# and returns success; maybe_install_bridge must never call die and must
# never affect the outcome of the harness install it follows.

BRIDGE_NPM_PACKAGE=@deepwind/bridge
BRIDGE_MIN_NODE_MAJOR=22

maybe_install_bridge() {
  if ! command -v npm >/dev/null 2>&1; then
    warn "bridge install skipped: npm was not found on PATH (install Node >=$BRIDGE_MIN_NODE_MAJOR, then run: npm i -g $BRIDGE_NPM_PACKAGE)"
    return 0
  fi
  if ! command -v node >/dev/null 2>&1; then
    warn "bridge install skipped: node was not found on PATH (install Node >=$BRIDGE_MIN_NODE_MAJOR, then run: npm i -g $BRIDGE_NPM_PACKAGE)"
    return 0
  fi

  bridge_node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null) || bridge_node_major=
  case "$bridge_node_major" in
    ''|*[!0-9]*)
      warn "bridge install skipped: could not determine the Node.js version (install Node >=$BRIDGE_MIN_NODE_MAJOR, then run: npm i -g $BRIDGE_NPM_PACKAGE)"
      return 0
      ;;
  esac
  if [ "$bridge_node_major" -lt "$BRIDGE_MIN_NODE_MAJOR" ]; then
    warn "bridge install skipped: Node.js $bridge_node_major is older than the required >=$BRIDGE_MIN_NODE_MAJOR (upgrade Node, then run: npm i -g $BRIDGE_NPM_PACKAGE)"
    return 0
  fi

  info "Installing the DeepWind bridge CLI ($BRIDGE_NPM_PACKAGE)..."
  if npm i -g "$BRIDGE_NPM_PACKAGE" >/dev/null 2>&1; then
    info "DeepWind bridge CLI installed. Next: pm33-bridge login && pm33-bridge register"
  else
    warn "bridge install failed (npm/network); the harness install is unaffected. Retry manually with: npm i -g $BRIDGE_NPM_PACKAGE"
  fi
  return 0
}
