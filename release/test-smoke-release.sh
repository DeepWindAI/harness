#!/usr/bin/env bash
# Exercise the release smoke harness without network access or published assets.
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/deepwind-smoke-test.XXXXXX")
FIXTURE_ROOT=$(CDPATH='' cd -- "$FIXTURE_ROOT" && pwd -P)
trap 'rm -rf "$FIXTURE_ROOT"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$FIXTURE_ROOT/bin" "$FIXTURE_ROOT/archive" "$FIXTURE_ROOT/tmp"
printf 'preserve fixture tmp root\n' > "$FIXTURE_ROOT/tmp/sentinel"
printf 'safe archive fixture\n' > "$FIXTURE_ROOT/archive/payload.txt"
printf 'fixture keyring\n' > "$FIXTURE_ROOT/trusted-keyring.gpg"

cat > "$FIXTURE_ROOT/installer.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$HOME" in
  *'//'*) printf '%s\n' 'deepwind-init: HOME is not canonical' >&2; exit 1 ;;
esac
printf '%s\n' "$HOME" >> "$DEEPWIND_SMOKE_HOME_LOG"
mkdir -p "$HOME/.claude/skills" "$HOME/.codex/agents"
printf 'fixture skill\n' > "$HOME/.claude/skills/fixture.md"
printf 'fixture role\n' > "$HOME/.codex/agents/fixture.md"
case " $* " in
  *' --configure-mcp '*)
    printf '%s\n' 'installed harness files remain available'
    ;;
esac
EOF
chmod 700 "$FIXTURE_ROOT/installer.sh"

cat > "$FIXTURE_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output=
head_request=0
url=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) output=$2; shift 2 ;;
    -*I*) head_request=1; shift ;;
    https://*) url=$1; shift ;;
    *) shift ;;
  esac
done

if [ "$head_request" -eq 1 ]; then
  case "$url" in
    */install) printf 'content-type: text/x-shellscript\n' ;;
    */get-started) printf 'content-type: text/html; charset=utf-8\n' ;;
    *) exit 22 ;;
  esac
  exit 0
fi

case "$url" in
  */install|*/deepwind-init-v1.2.3.sh)
    cp "$DEEPWIND_SMOKE_FIXTURE/installer.sh" "$output"
    ;;
  */get-started)
    printf '<html>Install DeepWind in fixture</html>\n' > "$output"
    ;;
  */deepwind-harness-claude-v1.2.3.tar.gz|*/deepwind-harness-codex-v1.2.3.tar.gz)
    tar -C "$DEEPWIND_SMOKE_FIXTURE/archive" -czf "$output" payload.txt
    ;;
  */SHA256SUMS)
    for asset in \
      deepwind-release-manifest.json \
      deepwind-release-manifest.json.asc \
      deepwind-release-provenance.json \
      public-keyring.json \
      deepwind-init-v1.2.3.sh \
      deepwind-harness-claude-v1.2.3.tar.gz \
      deepwind-harness-codex-v1.2.3.tar.gz; do
      printf '%064d  %s\n' 0 "$asset"
    done > "$output"
    ;;
  */deepwind-release-manifest.json|*/deepwind-release-provenance.json)
    printf '{}\n' > "$output"
    ;;
  */deepwind-release-manifest.json.asc|*/public-keyring.json)
    printf 'fixture release asset\n' > "$output"
    ;;
  *)
    printf 'unexpected fixture URL: %s\n' "$url" >&2
    exit 22
    ;;
esac
EOF

cat > "$FIXTURE_ROOT/bin/gpgv" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$FIXTURE_ROOT/bin/jq" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$FIXTURE_ROOT/bin/sha256sum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = -c ]; then
  exit 0
fi
for path in "$@"; do
  printf '%064d  %s\n' 0 "$path"
done
EOF
chmod 700 "$FIXTURE_ROOT/bin/"*

HOME_LOG="$FIXTURE_ROOT/home.log"
DEEPWIND_SMOKE_FIXTURE="$FIXTURE_ROOT" \
DEEPWIND_SMOKE_HOME_LOG="$HOME_LOG" \
TMPDIR="$FIXTURE_ROOT/tmp/" \
PATH="$FIXTURE_ROOT/bin:$PATH" \
bash "$ROOT/release/smoke-release.sh" \
  --version 1.2.3 \
  --website-url https://fixtures.invalid \
  --release-url https://fixtures.invalid/releases \
  --keyring "$FIXTURE_ROOT/trusted-keyring.gpg" \
  > "$FIXTURE_ROOT/smoke.log"

[ "$(wc -l < "$HOME_LOG" | tr -d '[:space:]')" -eq 3 ] \
  || fail 'fixture installer did not exercise install, check, and doctor paths'
while IFS= read -r smoke_home; do
  case "$smoke_home" in
    *'//'*) fail "smoke HOME is not canonical: $smoke_home" ;;
    "$FIXTURE_ROOT/tmp/"deepwind-release-smoke.*/home) ;;
    *) fail "smoke HOME escaped the fixture tmp root: $smoke_home" ;;
  esac
done < "$HOME_LOG"

[ -f "$FIXTURE_ROOT/tmp/sentinel" ] \
  || fail 'smoke cleanup removed the caller-owned tmp root'
[ "$(find "$FIXTURE_ROOT/tmp" -mindepth 1 ! -name sentinel -print | wc -l | tr -d '[:space:]')" -eq 0 ] \
  || fail 'smoke cleanup left temporary files behind'
grep -F 'PASS: immutable release v1.2.3' "$FIXTURE_ROOT/smoke.log" >/dev/null \
  || fail 'fixture smoke did not complete successfully'

printf 'PASS: release smoke canonical TMPDIR and cleanup contract\n'
