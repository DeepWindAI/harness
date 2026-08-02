#!/usr/bin/env bash
# Compile the formal DeepWind skill catalog into the two non-overlapping client
# surfaces: Claude aliases and the release-contained Codex plugin.  The catalog
# is the single inventory, so a skill addition updates both outputs.
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

catalog="$ROOT/release/skill-catalog.json"
[ -f "$catalog" ] || { printf 'missing skill catalog: %s\n' "$catalog" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { printf 'jq is required to compile the skill catalog\n' >&2; exit 2; }

jq -er '
  .formatVersion == 1 and
  (.skills | type == "array" and length > 0) and
  all(.skills[]; (.name | test("^deepwind-[a-z0-9-]+$")) and
    (.claudeSource | type == "string") and (.codexSource | type == "string"))
' "$catalog" >/dev/null || { printf 'invalid skill catalog\n' >&2; exit 2; }

compile_skill() {
  source_file=$1
  public_name=$2
  output_file=$3
  [ -f "$source_file" ] || { printf 'missing skill source: %s\n' "$source_file" >&2; exit 2; }
  mkdir -p "$(dirname -- "$output_file")"
  awk -v replacement="name: $public_name" '
    NR == 1 && $0 != "---" { print "skill source is missing YAML frontmatter: " FILENAME > "/dev/stderr"; exit 2 }
    NR == 2 {
      if ($0 !~ /^name: [a-z0-9-]+$/) {
        print "invalid skill name in " FILENAME ": " $0 > "/dev/stderr"; exit 2
      }
      print replacement
      next
    }
    { print }
  ' "$source_file" > "$output_file"
}

while IFS=$'\t' read -r public_name claude_source codex_source; do
  compile_skill "$ROOT/$claude_source" "$public_name" "$ROOT/skills/$public_name/SKILL.md"
  compile_skill "$ROOT/$codex_source" "$public_name" \
    "$ROOT/plugins/deepwind-harness/skills/$public_name/SKILL.md"
done < <(jq -r '.skills[] | [.name, .claudeSource, .codexSource] | @tsv' "$catalog")
