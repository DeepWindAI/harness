#!/usr/bin/env bash
# Reject mutable or obsolete installer references anywhere in shipped archives.
set -euo pipefail
IFS=$'\n\t'

fail() { printf 'release archive scan: %s\n' "$*" >&2; exit 1; }
[ "$#" -gt 0 ] || fail 'at least one release archive is required'

SCAN_TMP=$(mktemp -d "${TMPDIR:-/tmp}/deepwind-archive-scan.XXXXXX")
cleanup_scan() {
  find "$SCAN_TMP" -depth -type f -exec rm -f {} \; 2>/dev/null || true
  find "$SCAN_TMP" -depth -type d -exec rmdir {} \; 2>/dev/null || true
}
trap cleanup_scan EXIT HUP INT TERM

FORBIDDEN_PATTERN='raw[.]githubusercontent[.]com/[^[:space:]"'\'']+/main/|/archive/refs/heads/main|/releases/download/main|deepwind[.]ai/install/deepwind-init[.]sh|github[.]com/(deepwind/deepwind-install|DeepWindAI/deepwind-install)|[.]deepwind/install/VERSION|DEEPWIND_VERSION_MANIFEST_URL'

archive_index=0
for archive_path in "$@"; do
  archive_index=$((archive_index + 1))
  if [ ! -f "$archive_path" ] || [ -L "$archive_path" ]; then
    fail "archive is missing or unsafe: $archive_path"
  fi
  archive_contents="$SCAN_TMP/archive-$archive_index.contents"
  # Stream regular-file bodies into a private temporary file instead of
  # extracting paths. This scanner therefore cannot follow an archive path,
  # symlink, or traversal entry outside its staging directory.
  tar -xOzf "$archive_path" > "$archive_contents" \
    || fail "cannot read archive contents: $archive_path"
  if grep -EIq "$FORBIDDEN_PATTERN" "$archive_contents"; then
    fail "mutable or obsolete installer reference in archive: $archive_path"
  fi
done

printf 'PASS: %s release archive(s) contain no mutable or obsolete installer references\n' \
  "$archive_index"
