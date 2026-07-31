#!/usr/bin/env bash
# Generate the globally discoverable DeepWind harness skill aliases from the
# canonical Claude skill sources. The release workflow runs this before it
# archives a target and rejects any uncommitted generated output.
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

for skill in prep planner coordinator discipline; do
  source_file="$ROOT/skills/harness-$skill/SKILL.md"
  [ -f "$source_file" ] || {
    printf 'missing canonical harness skill: %s\n' "$source_file" >&2
    exit 2
  }

  for alias_root in skills codex/skills .agents/skills; do
    alias_file="$ROOT/$alias_root/deepwind-harness-$skill/SKILL.md"
    mkdir -p "$(dirname -- "$alias_file")"
    awk \
      -v expected="name: harness-$skill" \
      -v replacement="name: deepwind-harness-$skill" '
        NR == 2 {
          if ($0 != expected) {
            printf "unexpected skill name in %s: %s\\n", FILENAME, $0 > "/dev/stderr"
            exit 2
          }
          print replacement
          next
        }
        { print }
      ' "$source_file" > "$alias_file"
  done
done
