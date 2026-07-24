#!/usr/bin/env bash
# Verify an already-published, immutable DeepWind release and its website route.
# This script never creates a release, deploys a website, or starts OAuth.
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<'EOF'
usage: smoke-release.sh --version SEMVER --website-url HTTPS_URL --keyring FILE [--release-url HTTPS_URL]

The version must name an existing immutable GitHub Release. --website-url is
the preview or production deployment that has DEEPWIND_INSTALL_RELEASE_VERSION
set to that same version. --keyring is the reviewed binary GPG keyring embedded
in that release's bootstrap; it is never downloaded by this smoke test.
EOF
  exit 2
}

fail() { printf 'release smoke: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }
sha256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
is_https_url() { printf '%s' "$1" | grep -Eq '^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^?#[:space:]]*)?$'; }

VERSION=
WEBSITE_URL=
RELEASE_URL=
KEYRING=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) [ "$#" -ge 2 ] || usage; VERSION=$2; shift 2 ;;
    --website-url) [ "$#" -ge 2 ] || usage; WEBSITE_URL=${2%/}; shift 2 ;;
    --release-url) [ "$#" -ge 2 ] || usage; RELEASE_URL=${2%/}; shift 2 ;;
    --keyring) [ "$#" -ge 2 ] || usage; KEYRING=$2; shift 2 ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
done

printf '%s' "$VERSION" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$' \
  || fail 'version must be strict semver'
is_https_url "$WEBSITE_URL" || fail '--website-url must be an HTTPS URL'
if [ ! -r "$KEYRING" ] || [ -L "$KEYRING" ]; then
  fail '--keyring must be a readable regular file'
fi
[ -s "$KEYRING" ] || fail '--keyring is empty; release smoke must fail closed'

TAG="v$VERSION"
if [ -z "$RELEASE_URL" ]; then
  RELEASE_URL="https://github.com/DeepWindAI/harness/releases/download/$TAG"
fi
is_https_url "$RELEASE_URL" || fail '--release-url must be an HTTPS URL'

for command in curl gpgv jq grep awk cmp mktemp find sort; do need "$command"; done
[ "$(id -u)" -ne 0 ] || fail 'installer smoke must run as a non-root user'
TMP=$(mktemp -d "${TMPDIR:-/tmp}/deepwind-release-smoke.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fetch_release_asset() {
  asset=$1
  curl -fLsS --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 60 \
    "$RELEASE_URL/$asset" -o "$TMP/$asset" || fail "cannot fetch immutable release asset: $asset"
}

for asset in deepwind-release-manifest.json deepwind-release-manifest.json.asc \
  deepwind-release-provenance.json public-keyring.json SHA256SUMS \
  "deepwind-init-v$VERSION.sh" "deepwind-harness-claude-v$VERSION.tar.gz" \
  "deepwind-harness-codex-v$VERSION.tar.gz"; do
  fetch_release_asset "$asset"
done

gpgv --keyring "$KEYRING" "$TMP/deepwind-release-manifest.json.asc" \
  "$TMP/deepwind-release-manifest.json" >/dev/null 2>&1 \
  || fail 'published manifest signature does not verify with the reviewed keyring'

(cd "$TMP" && \
  grep -E "^[a-f0-9]{64}  (deepwind-release-manifest.json|deepwind-release-manifest.json.asc|deepwind-release-provenance.json|public-keyring.json|deepwind-init-v$VERSION.sh|deepwind-harness-claude-v$VERSION.tar.gz|deepwind-harness-codex-v$VERSION.tar.gz)$" SHA256SUMS \
    > checked-sums && \
  [ "$(wc -l < checked-sums | tr -d '[:space:]')" = 7 ] && \
  if command -v sha256sum >/dev/null 2>&1; then sha256sum -c checked-sums; else
    while read -r digest asset; do [ "$(sha256 "$asset")" = "$digest" ] || exit 1; done < checked-sums
  fi) || fail 'published SHA256SUMS does not cover or match every required asset'

jq -e --arg version "$VERSION" --arg tag "$TAG" '
  .formatVersion == 1 and .version == $version and .tag == $tag and
  .provenance.repository == "DeepWindAI/harness" and
  .bootstrap.file == ("deepwind-init-v" + $version + ".sh") and
  ([.archives[].target] | sort) == ["claude", "codex"] and
  .signing.signatureFile == "deepwind-release-manifest.json.asc"
' "$TMP/deepwind-release-manifest.json" >/dev/null \
  || fail 'manifest does not describe the requested dual-target release'

jq -e --arg tag "$TAG" '
  .formatVersion == 1 and .repository == "DeepWindAI/harness" and .tag == $tag and
  .manifest == "deepwind-release-manifest.json"
' "$TMP/deepwind-release-provenance.json" >/dev/null \
  || fail 'provenance does not bind the manifest to the requested immutable tag'

if grep -Eq 'raw[.]githubusercontent[.]com/[^[:space:]]+/main/|/archive/refs/heads/main|/releases/download/main/' \
  "$TMP/deepwind-init-v$VERSION.sh" "$TMP/deepwind-release-manifest.json" "$TMP/deepwind-release-provenance.json"; then
  fail 'published release contains a mutable main reference'
fi
bash "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/scan-release-archives.sh" \
  "$TMP/deepwind-harness-claude-v$VERSION.tar.gz" \
  "$TMP/deepwind-harness-codex-v$VERSION.tar.gz" >/dev/null \
  || fail 'published target archive contains a mutable or obsolete installer reference'

curl -fLsSI --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 60 \
  "$WEBSITE_URL/install" > "$TMP/install.headers" \
  || fail 'website /install HEAD request failed'
grep -Eqi '^content-type:[[:space:]]*text/x-shellscript([;[:space:]]|$)' "$TMP/install.headers" \
  || fail 'website /install does not advertise text/x-shellscript'
curl -fLsS --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 60 \
  "$WEBSITE_URL/install" -o "$TMP/public-install.sh" \
  || fail 'website /install GET request failed'
cmp "$TMP/public-install.sh" "$TMP/deepwind-init-v$VERSION.sh" \
  || fail 'website /install body is not the exact version-pinned bootstrap'

curl -fLsSI --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 60 \
  "$WEBSITE_URL/get-started" > "$TMP/get-started.headers" \
  || fail 'website /get-started HEAD request failed'
grep -Eqi '^content-type:[[:space:]]*text/html([;[:space:]]|$)' "$TMP/get-started.headers" \
  || fail 'website /get-started does not advertise HTML'
curl -fLsS --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 60 \
  "$WEBSITE_URL/get-started" -o "$TMP/get-started.html" \
  || fail 'website /get-started GET request failed'
grep -F 'Install DeepWind in' "$TMP/get-started.html" >/dev/null \
  || fail 'website /get-started does not render browser onboarding'

SMOKE_HOME="$TMP/home"
mkdir -m 700 "$SMOKE_HOME"
HOME="$SMOKE_HOME" bash "$TMP/public-install.sh" --version "$VERSION" --target both \
  > "$TMP/both-target-install.log" 2>&1 \
  || fail 'exact public bootstrap failed the both-target install smoke'
[ -d "$SMOKE_HOME/.claude/skills" ] || fail 'both-target smoke did not install Claude skills'
[ -d "$SMOKE_HOME/.codex/agents" ] || fail 'both-target smoke did not install Codex roles'
HOME="$SMOKE_HOME" bash "$TMP/public-install.sh" --version "$VERSION" --target both --check \
  > "$TMP/both-target-check.log" 2>&1 \
  || fail 'both-target check did not pass after installation'

# The doctor path is intentionally exercised with a fixture Codex binary. The
# non-interactive shell prevents OAuth onboarding, while the failing `mcp get`
# verifies redacted doctor failure cannot mutate a completed installation.
mkdir -m 700 "$TMP/fake-bin"
cat > "$TMP/fake-bin/codex" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = mcp ] && [ "${2:-}" = get ]; then
  printf '%s\n' 'fixture connector unavailable' >&2
  exit 1
fi
printf '%s\n' 'unexpected fixture codex invocation' >&2
exit 64
EOF
chmod 700 "$TMP/fake-bin/codex"
find "$SMOKE_HOME" -type f -exec sh -c 'if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi' sh {} \; | sort > "$TMP/before-doctor.sha256"
HOME="$SMOKE_HOME" PATH="$TMP/fake-bin:$PATH" bash "$TMP/public-install.sh" \
  --version "$VERSION" --target both --configure-mcp > "$TMP/failed-doctor.log" 2>&1 \
  || fail 'failed doctor path unexpectedly failed installation'
grep -F 'installed harness files remain available' "$TMP/failed-doctor.log" >/dev/null \
  || fail 'failed doctor path was not reported as non-destructive'
find "$SMOKE_HOME" -type f -exec sh -c 'if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi' sh {} \; | sort > "$TMP/after-doctor.sha256"
cmp "$TMP/before-doctor.sha256" "$TMP/after-doctor.sha256" \
  || fail 'failed doctor changed installed files'

printf 'PASS: immutable release %s and website route %s\n' "$TAG" "$WEBSITE_URL"
