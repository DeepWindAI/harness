# shellcheck shell=bash
# Portable best-effort timeout wrapper for post-commit network steps.
#
# maybe_install_bridge (lib/bridge-install.sh) and the Codex MCP registration
# and OAuth calls (lib/codex-mcp.sh) both run only after apply_transaction has
# committed the signed, journaled release install. A true network hang in
# either call blocks the installer at the very end even though nothing is
# corrupted (the transaction already committed). Wrapping those calls with a
# timeout turns an indefinite hang into a bounded, warn-and-continue failure
# like any other best-effort post-commit step.
#
# `timeout` is GNU coreutils and is not guaranteed to exist: macOS ships bash
# 3.2 with no `timeout` binary unless GNU coreutils is installed via Homebrew
# (which provides it as `gtimeout` to avoid clobbering the BSD userland). This
# helper degrades gracefully across three cases and must never itself be the
# reason a best-effort step fails: `timeout` if present, else `gtimeout` if
# present, else run the command with no timeout at all.

NET_TIMEOUT_SECONDS=120

run_with_net_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$NET_TIMEOUT_SECONDS" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$NET_TIMEOUT_SECONDS" "$@"
  else
    "$@"
  fi
}
