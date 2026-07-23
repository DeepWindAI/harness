# shellcheck shell=bash disable=SC2034
# Immutable release resolution, signature verification, and archive validation.

RELEASES_BASE=https://github.com/DeepWindAI/harness/releases
LATEST_RELEASE_URL=https://api.github.com/repos/DeepWindAI/harness/releases/latest

fetch_release_file() {
  release_name=$1
  output_path=$2
  if [ "${DEEPWIND_INSTALL_TESTING:-0}" = 1 ]; then
    [ -n "${DEEPWIND_RELEASE_DIR:-}" ] || die "test release directory is required"
    [ -f "$DEEPWIND_RELEASE_DIR/$release_name" ] || die "fixture asset is missing: $release_name"
    cp "$DEEPWIND_RELEASE_DIR/$release_name" "$output_path"
  else
    curl -fLsS --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 120 \
      "$RELEASES_BASE/download/v$VERSION/$release_name" -o "$output_path" \
      || die "failed to fetch immutable release asset: $release_name"
  fi
}

resolve_version() {
  [ -z "$VERSION" ] || return 0
  if [ "${DEEPWIND_INSTALL_TESTING:-0}" = 1 ]; then
    [ -f "${DEEPWIND_RELEASE_DIR:-}/deepwind-release-manifest.json" ] \
      || die "fixture manifest is missing"
    VERSION=$(jq -er '.version' "$DEEPWIND_RELEASE_DIR/deepwind-release-manifest.json") \
      || die "fixture manifest has no version"
  else
    latest_json="$WORK_DIR/latest-release.json"
    curl -fLsS --proto '=https' --tlsv1.2 --connect-timeout 10 --max-time 30 \
      "$LATEST_RELEASE_URL" -o "$latest_json" || die "cannot resolve latest immutable release"
    latest_tag=$(jq -er '.tag_name' "$latest_json") || die "latest release has no tag"
    VERSION=${latest_tag#v}
  fi
  printf '%s' "$VERSION" | grep -Eq \
    '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$' \
    || die "resolved release is not strict semver"
}

verify_manifest_signature() {
  manifest_path=$1
  signature_path=$2
  [ -n "${EMBEDDED_TRUSTED_KEYRING_B64:-}" ] \
    || die "no trusted release keyring is embedded; release owners must provision it"
  trusted_keyring="$WORK_DIR/trusted-release-keyring.gpg"
  if printf '%s' "$EMBEDDED_TRUSTED_KEYRING_B64" | base64 -d > "$trusted_keyring" 2>/dev/null; then
    :
  elif printf '%s' "$EMBEDDED_TRUSTED_KEYRING_B64" | base64 -D > "$trusted_keyring" 2>/dev/null; then
    :
  else
    die "embedded release keyring is malformed"
  fi
  need_command gpgv
  gpgv --keyring "$trusted_keyring" "$signature_path" "$manifest_path" >/dev/null 2>&1 \
    || die "release manifest signature verification failed"
}

validate_manifest() {
  manifest_path=$1
  jq -e \
    --arg version "$VERSION" --arg tag "v$VERSION" --arg channel "$CHANNEL" '
      .formatVersion == 1 and
      .version == $version and .tag == $tag and .channel == $channel and
      .provenance.repository == "DeepWindAI/harness" and
      (.provenance.revision | test("^[0-9a-f]{7,64}$")) and
      (.endpoint.alias | test("^[a-z0-9][a-z0-9-]{0,62}$")) and
      (.endpoint.url | test("^https://[A-Za-z0-9.-]+(/[^?#]*)?$")) and
      (.archives | length >= 1) and
      ([.archives[].target] | unique | length) == (.archives | length) and
      (.signing.signatureFile == "deepwind-release-manifest.json.asc") and
      (.signing.keyId | test("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")) and
      all(.archives[];
        (.target == "claude" or .target == "codex") and
        (.file | test("^deepwind-harness-(claude|codex)-v[0-9A-Za-z.+-]+[.]tar[.]gz$")) and
        (.sha256 | test("^[a-f0-9]{64}$")) and
        (.bytes | type == "number" and . > 0 and . <= 104857600) and
        (.files | type == "array" and length > 0 and length <= 2000 and
          (unique | length) == length) and
        all(.files[];
          type == "string" and length > 0 and length <= 240 and
          test("^[A-Za-z0-9._/@+-]+$") and
          (startswith("/") | not) and
          (test("(^|/)[.][.]?(/|$)") | not)
        )
      )
    ' "$manifest_path" >/dev/null || die "release manifest violates installer limits"
  signing_not_before=$(jq -er '.signing.notBefore' "$manifest_path")
  signing_not_after=$(jq -er '.signing.notAfter' "$manifest_path")
  printf '%s\n%s\n' "$signing_not_before" "$signing_not_after" \
    | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
    || die "manifest signing window is not canonical UTC"
  signing_now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  [[ "$signing_not_before" < "$signing_not_after" ]] \
    && [[ "$signing_now" > "$signing_not_before" || "$signing_now" = "$signing_not_before" ]] \
    && [[ "$signing_now" < "$signing_not_after" || "$signing_now" = "$signing_not_after" ]] \
    || die "manifest signing window is not currently valid"
}

check_free_space() {
  required_bytes=$(jq \
    --arg target "$TARGET" '
      [.archives[]
        | select($target == "both" or .target == $target)
        | .bytes] | add * 4
    ' "$MANIFEST_FILE")
  available_kb=$(df -Pk "$HOME" | awk 'NR == 2 { print $4 }')
  case "$available_kb" in ''|*[!0-9]*) die "cannot determine free space" ;; esac
  available_bytes=$((available_kb * 1024))
  [ "$available_bytes" -ge "$required_bytes" ] \
    || die "insufficient free space for verified staging and rollback"
}

target_selected() {
  selected=$1
  [ "$TARGET" = both ] || [ "$TARGET" = "$selected" ]
}

verify_archive() {
  archive_target=$1
  archive_file=$(jq -er --arg target "$archive_target" \
    '.archives[] | select(.target == $target) | .file' "$MANIFEST_FILE") \
    || die "manifest has no $archive_target archive"
  case "$archive_file" in
    "deepwind-harness-$archive_target-v$VERSION.tar.gz") ;;
    *) die "archive filename does not match target and version" ;;
  esac
  archive_path="$WORK_DIR/$archive_file"
  fetch_release_file "$archive_file" "$archive_path"

  expected_sha=$(jq -r --arg target "$archive_target" \
    '.archives[] | select(.target == $target) | .sha256' "$MANIFEST_FILE")
  expected_bytes=$(jq -r --arg target "$archive_target" \
    '.archives[] | select(.target == $target) | .bytes' "$MANIFEST_FILE")
  [ "$(sha256_file "$archive_path")" = "$expected_sha" ] || die "$archive_target archive digest mismatch"
  actual_bytes=$(wc -c < "$archive_path" | tr -d '[:space:]')
  [ "$actual_bytes" = "$expected_bytes" ] || die "$archive_target archive byte length mismatch"

  listing="$WORK_DIR/$archive_target-files.json"
  tar -tzf "$archive_path" \
    | sed -e 's#^\./##' -e '/^$/d' \
    | LC_ALL=C sort | jq -Rsc 'split("\n") | map(select(length > 0))' > "$listing" \
    || die "cannot list $archive_target archive"
  jq -e --arg target "$archive_target" --slurpfile actual "$listing" \
    '(.archives[] | select(.target == $target) | .files | sort) == $actual[0]' \
    "$MANIFEST_FILE" >/dev/null || die "$archive_target archive member list mismatch"

  tar -tvzf "$archive_path" | awk '
    substr($0, 1, 1) != "-" && substr($0, 1, 1) != "d" { bad=1 }
    END { exit bad }
  ' || die "$archive_target archive contains a link or special file"
  printf '%s\n' "$archive_path"
}

prepare_verified_release() {
  resolve_version
  MANIFEST_FILE="$WORK_DIR/deepwind-release-manifest.json"
  SIGNATURE_FILE="$WORK_DIR/deepwind-release-manifest.json.asc"
  fetch_release_file deepwind-release-manifest.json "$MANIFEST_FILE"
  fetch_release_file deepwind-release-manifest.json.asc "$SIGNATURE_FILE"
  verify_manifest_signature "$MANIFEST_FILE" "$SIGNATURE_FILE"
  validate_manifest "$MANIFEST_FILE"

  CLAUDE_ARCHIVE=
  CODEX_ARCHIVE=
  if target_selected claude; then CLAUDE_ARCHIVE=$(verify_archive claude); fi
  if target_selected codex; then CODEX_ARCHIVE=$(verify_archive codex); fi
  check_free_space
}
