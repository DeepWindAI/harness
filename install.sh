#!/usr/bin/env bash
# Local entry point for the same signed, immutable release installer served by
# https://deepwind.ai/install. This wrapper never installs from a mutable clone.
set -euo pipefail
IFS=$'\n\t'
umask 077

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec bash "$SCRIPT_DIR/deepwind-init.sh" "$@"
