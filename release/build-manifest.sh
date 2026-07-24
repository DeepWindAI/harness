#!/usr/bin/env bash
# Build a deterministic manifest for already-built, immutable release archives.
# This script does not fetch, extract, or trust a network resource.
set -euo pipefail
IFS=$'\n\t'

die() { printf 'error: %s\n' "$*" >&2; exit 2; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }
sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}
usage() { cat >&2 <<'EOF'
usage: build-manifest.sh --version SEMVER --channel staging|production --endpoint-alias NAME \
  --endpoint-url HTTPS_URL --key-id ID --not-before RFC3339 --not-after RFC3339 \
  --source-revision HEX --bootstrap /absolute/deepwind-init-vSEMVER.sh \
  --archive target=/absolute/archive.tar.gz [--archive ...] --output FILE
EOF
exit 2; }

VERSION= CHANNEL= ENDPOINT_ALIAS= ENDPOINT_URL= KEY_ID= NOT_BEFORE= NOT_AFTER= REVISION= BOOTSTRAP= OUTPUT=
ARCHIVES=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version|--channel|--endpoint-alias|--endpoint-url|--key-id|--not-before|--not-after|--source-revision|--bootstrap|--output)
      [ "$#" -ge 2 ] || usage
      case "$1" in
        --version) VERSION=$2;; --channel) CHANNEL=$2;; --endpoint-alias) ENDPOINT_ALIAS=$2;;
        --endpoint-url) ENDPOINT_URL=$2;; --key-id) KEY_ID=$2;; --not-before) NOT_BEFORE=$2;;
        --not-after) NOT_AFTER=$2;; --source-revision) REVISION=$2;; --bootstrap) BOOTSTRAP=$2;;
        --output) OUTPUT=$2;;
      esac
      shift 2;;
    --archive) [ "$#" -ge 2 ] || usage; ARCHIVES+=("$2"); shift 2;;
    *) usage;;
  esac
done

need jq; need tar; need awk
[ -n "$VERSION" ] && [ -n "$CHANNEL" ] && [ -n "$ENDPOINT_ALIAS" ] && [ -n "$ENDPOINT_URL" ] || usage
[ -n "$KEY_ID" ] && [ -n "$NOT_BEFORE" ] && [ -n "$NOT_AFTER" ] && [ -n "$REVISION" ] || usage
[ -n "$BOOTSTRAP" ] && [ -n "$OUTPUT" ] || usage
[ "${#ARCHIVES[@]}" -gt 0 ] || die 'at least one --archive is required'
printf '%s' "$VERSION" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$' || die 'version must be strict semver'
case "$CHANNEL" in staging|production) ;; *) die 'channel must be staging or production';; esac
printf '%s' "$ENDPOINT_ALIAS" | grep -Eq '^[a-z0-9][a-z0-9-]{0,62}$' || die 'invalid endpoint alias'
printf '%s' "$ENDPOINT_URL" | grep -Eq '^https://[A-Za-z0-9.-]+(/[^?#]*)?$' || die 'endpoint must be an HTTPS URL without query or fragment'
printf '%s' "$KEY_ID" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$' || die 'invalid key id'
printf '%s' "$REVISION" | grep -Eq '^[0-9a-f]{7,64}$' || die 'source revision must be lowercase hexadecimal'
printf '%s\n%s\n' "$NOT_BEFORE" "$NOT_AFTER" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' || die 'signing dates must be UTC RFC3339 timestamps'
[[ "$NOT_BEFORE" < "$NOT_AFTER" ]] || die 'signing validity window is invalid'

[ -f "$BOOTSTRAP" ] || die "bootstrap does not exist: $BOOTSTRAP"
bootstrap_filename=$(basename -- "$BOOTSTRAP")
[ "$bootstrap_filename" = "deepwind-init-v${VERSION}.sh" ] \
  || die "bootstrap filename must be deepwind-init-v${VERSION}.sh"
[ "$(sed -n '1p' "$BOOTSTRAP")" = '#!/usr/bin/env bash' ] \
  || die 'bootstrap must begin with the reviewed bash shebang'
bootstrap_sha=$(sha256 "$BOOTSTRAP")
bootstrap_bytes=$(wc -c < "$BOOTSTRAP" | tr -d '[:space:]')
[ "$bootstrap_bytes" -gt 0 ] || die 'bootstrap must not be empty'
[ "$bootstrap_bytes" -le 2097152 ] || die 'bootstrap exceeds the 2 MiB release limit'
bootstrap_json=$(jq -nS \
  --arg file "$bootstrap_filename" --arg sha "$bootstrap_sha" --argjson bytes "$bootstrap_bytes" \
  '{file:$file,sha256:$sha,bytes:$bytes}')

archive_json='[]'
seen_targets=' '
for item in "${ARCHIVES[@]}"; do
  target=${item%%=*}; path=${item#*=}
  [ "$target" != "$item" ] && [ -n "$path" ] || die "archive must be target=path: $item"
  case "$target" in claude|codex) ;; *) die "unsupported target: $target";; esac
  case "$seen_targets" in *" $target "*) die "duplicate target: $target";; esac
  seen_targets="$seen_targets$target "
  [ -f "$path" ] || die "archive does not exist: $path"
  filename=$(basename -- "$path")
  [ "$filename" = "deepwind-harness-${target}-v${VERSION}.tar.gz" ] || die "archive filename must be deepwind-harness-${target}-v${VERSION}.tar.gz"
  entries=$(tar -tzf "$path") || die "cannot read archive: $path"
  [ -n "$entries" ] || die "archive is empty: $path"
  normalized=$(printf '%s\n' "$entries" | awk '
    /^\// { exit 1 }
    {
      path = $0
      while (path ~ /^\.\//) sub(/^\.\//, "", path)
      if (path == "") next
      if (path ~ /(^|\/)\.\.?(\/|$)/) exit 1
      if (seen[path]++) exit 1
      print path
    }
  ') || die "archive has duplicate or escaping path: $path"
  [ -n "$normalized" ] || die "archive contains no files: $path"
  files=$(printf '%s\n' "$normalized" | LC_ALL=C sort | jq -Rsc 'split("\n") | map(select(length > 0))')
  digest=$(sha256 "$path")
  bytes=$(wc -c < "$path" | tr -d '[:space:]')
  archive_json=$(jq -c --arg target "$target" --arg file "$filename" --arg sha "$digest" --argjson bytes "$bytes" --argjson files "$files" \
    '. + [{target:$target,file:$file,sha256:$sha,bytes:$bytes,files:$files}]' <<<"$archive_json")
done

tmp="${OUTPUT}.tmp.$$"
umask 077
jq -nS \
  --arg version "$VERSION" --arg tag "v$VERSION" --arg channel "$CHANNEL" \
  --arg alias "$ENDPOINT_ALIAS" --arg url "$ENDPOINT_URL" --arg key "$KEY_ID" \
  --arg notBefore "$NOT_BEFORE" --arg notAfter "$NOT_AFTER" --arg revision "$REVISION" \
  --argjson bootstrap "$bootstrap_json" --argjson archives "$archive_json" \
  '{formatVersion:1,version:$version,tag:$tag,channel:$channel,endpoint:{alias:$alias,url:$url},signing:{keyId:$key,notBefore:$notBefore,notAfter:$notAfter,signatureFile:"deepwind-release-manifest.json.asc"},provenance:{repository:"DeepWindAI/harness",revision:$revision},bootstrap:$bootstrap,archives:($archives|sort_by(.target))}' > "$tmp"

jq -e '
  .formatVersion == 1 and
  (.version|test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$")) and
  (.tag == ("v" + .version)) and
  (.bootstrap.file == ("deepwind-init-v" + .version + ".sh")) and
  (.bootstrap.sha256|test("^[a-f0-9]{64}$")) and
  (.bootstrap.bytes > 0) and
  (.archives|length > 0) and
  all(.archives[]; (.sha256|test("^[a-f0-9]{64}$")) and (.bytes > 0) and (.files|length > 0))
' "$tmp" >/dev/null || { rm -f "$tmp"; die 'generated manifest violates schema invariants'; }
mv -f "$tmp" "$OUTPUT"
