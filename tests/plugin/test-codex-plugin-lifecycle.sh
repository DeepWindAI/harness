#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)

if ! command -v codex >/dev/null 2>&1; then
  printf 'SKIP: codex CLI is not installed\n'
  exit 0
fi

fixture=$(realpath "$(mktemp -d "${TMPDIR:-/tmp}/deepwind-plugin-lifecycle.XXXXXX")")
trap 'find "$fixture" -depth -type f -exec rm -f {} \; 2>/dev/null || true; find "$fixture" -depth -type d -exec rmdir {} \; 2>/dev/null || true' EXIT
release_root="$fixture/release"
fixture_home="$fixture/home"
mkdir -p "$release_root/.agents/plugins" "$release_root/plugins" "$fixture_home"
cp "$ROOT/.agents/plugins/marketplace.json" "$release_root/.agents/plugins/marketplace.json"
cp -R "$ROOT/plugins/deepwind-harness" "$release_root/plugins/deepwind-harness"

run_codex() {
  env -u CODEX_HOME HOME="$fixture_home" codex "$@"
}

run_codex plugin marketplace add "$release_root" --json >/dev/null
run_codex plugin add deepwind-harness@deepwind --json >/dev/null
installed=$(run_codex plugin list --json)
jq -e --arg root "$release_root" '
  any(.installed[];
    .pluginId == "deepwind-harness@deepwind" and
    .version == "1.1.6" and
    .installed == true and
    .enabled == true and
    .marketplaceSource.source == $root
  )
' <<<"$installed" >/dev/null

manifest="$release_root/plugins/deepwind-harness/.codex-plugin/plugin.json"
jq '.version = "1.1.7"' "$manifest" > "$manifest.next"
mv "$manifest.next" "$manifest"
run_codex plugin add deepwind-harness@deepwind --json >/dev/null
upgraded=$(run_codex plugin list --json)
jq -e '
  any(.installed[];
    .pluginId == "deepwind-harness@deepwind" and .version == "1.1.7"
  )
' <<<"$upgraded" >/dev/null

run_codex plugin remove deepwind-harness@deepwind --json >/dev/null
removed=$(run_codex plugin list --json)
jq -e '
  all(.installed[]; .pluginId != "deepwind-harness@deepwind")
' <<<"$removed" >/dev/null
run_codex plugin marketplace remove deepwind --json >/dev/null

[ ! -e "$fixture_home/.agents/plugins/marketplace.json" ] || {
  printf 'FAIL: lifecycle wrote a user marketplace catalog\n' >&2
  exit 1
}

printf 'PASS: isolated Codex plugin fresh/check/upgrade/removal lifecycle\n'
