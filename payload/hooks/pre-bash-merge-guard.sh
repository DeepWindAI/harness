#!/usr/bin/env bash
# Pre-Bash merge guard (Claude Code PreToolUse hook).
# Reads JSON from stdin; BLOCKS a `gh pr merge <PR#>` when that PR touches
# security-sensitive paths (per .deepwind/sensitive-paths) and carries no review
# signal (approving review or reviewed:code label). Delegates the decision to
# check-sensitive-review.sh (shared with guarded-merge.sh).
#
# Why this exists
#   PR #1045 (pm-33-core) self-merged 34.6k lines (an "agent-executes-on-user-machines"
#   feature) with reviews=0. Branch protection can't enforce review on a private
#   free-plan repo, so the runtime hook is the hard gate for Claude coordinators: it
#   turns a forgetful `gh pr merge` into a required, deliberate "get it reviewed first"
#   step. Shipped in the DeepWind harness bundle so any installed repo gets the gate.
#
# Scope / limits
#   - Only fires on an EXPLICIT `gh pr merge <number>`. A bare `gh pr merge` (merges
#     the current branch's PR, no number) is resolved + gated too.
#   - Advisory-safe: any tooling error (no gh, undeterminable PR, no check script) →
#     exit 0, never blocks a merge on infra failure.
#
# Disable: rm ~/.claude/hooks/pre-bash-merge-guard.sh   Quiet-bypass: MERGE_GUARD=0
set -euo pipefail

[ "${MERGE_GUARD:-1}" = "0" ] && exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // .command // ""' 2>/dev/null || echo "")
[ -z "$CMD" ] && exit 0

# Only care about `gh pr merge`.
echo "$CMD" | grep -qE '(^|[;&| ])gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)' || exit 0

# Extract the PR number ANYWHERE in the merge invocation (not just right after
# `merge` — `gh pr merge --admin --squash 1045` is a valid form). `gh pr merge` has
# value-taking flags whose ARGUMENT is a bare token that must NOT be mistaken for the
# PR number, or the gate would check the wrong PR (parser-differential escape):
#   -A|--author-email  -b|--body  -F|--body-file  --match-head-commit  -t|--subject  -R|--repo
MERGE_ARGS=$(echo "$CMD" | sed -E 's/.*gh[[:space:]]+pr[[:space:]]+merge//')

# `-R/--repo` (space- or =-form) points the merge at a repo this gate does NOT
# validate (check-sensitive-review resolves the CURRENT repo). Fail CLOSED rather
# than gate the wrong repo — route the caller to the explicit guarded path.
# Catches every -R/--repo form: `-R x`, `--repo x`, `--repo=x`, glued `-Rx`, and
# shorthand clusters ending in R (`-sR x`, `-sRx`). Capital R matches ONLY the repo
# flag — lowercase -r/--rebase never trip it.
if printf '%s' " $MERGE_ARGS " | grep -qE '[[:space:]](--repo([[:space:]]|=)|-[A-Za-z]*R)'; then
  echo "🚫 merge-guard: refusing a cross-repo \`gh pr merge -R/--repo …\` — this hook only gates the current repo. Use guarded-merge.sh, or drop -R to merge here." >&2
  exit 2
fi

PR=""
skip_next=0
for tok in $MERGE_ARGS; do
  if [ "$skip_next" = 1 ]; then skip_next=0; continue; fi
  case "$tok" in
    -A|--author-email|-b|--body|-F|--body-file|--match-head-commit|-t|--subject)
      skip_next=1; continue ;;   # consume this flag's VALUE token (never the PR#)
    -*) continue ;;              # boolean flag, or --flag=value (value not a separate token)
    *[!0-9]*|'') continue ;;     # non-integer / empty
    *) PR="$tok"; break ;;
  esac
done
# Bare `gh pr merge` (no number) merges the CURRENT branch's PR — resolve + gate it
# so a sensitive current-branch merge can't slip past by omitting the number.
[ -z "$PR" ] && PR=$(gh pr view --json number -q .number 2>/dev/null || true)
[ -z "$PR" ] && exit 0   # no PR resolvable (nothing to merge) — can't assess; fail open.

# Resolve check-sensitive-review.sh. Precedence:
#   1. explicit override (DEEPWIND_CHECK_SENSITIVE),
#   2. a repo-vendored copy (pm-33-core-style scripts/git/),
#   3. the globally-installed DeepWind bundle copy (~/.deepwind/bin, or DEEPWIND_BIN_DIR).
# Absent everywhere → nothing to enforce (fail open). This lets the same hook work both
# in a repo that vendors the gate and on a machine where only the bundle is installed.
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
CHECK=""
for candidate in \
  "${DEEPWIND_CHECK_SENSITIVE:-}" \
  "$ROOT/scripts/git/check-sensitive-review.sh" \
  "${DEEPWIND_BIN_DIR:-$HOME/.deepwind/bin}/check-sensitive-review.sh"
do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then CHECK="$candidate"; break; fi
done
[ -z "$CHECK" ] && exit 0   # gate not present anywhere — nothing to enforce.

TMP=$(mktemp)
set +e
"$CHECK" "$PR" 2>"$TMP"
rc=$?
set -e

if [ "$rc" -eq 1 ]; then
  {
    echo "🚫 merge-guard blocked \`gh pr merge $PR\`."
    cat "$TMP"
    echo
    echo "This is the coordinator-side enforcement for the PR #1045 process gap"
    echo "(branch protection is unavailable on private free-plan repos)."
  } >&2
  rm -f "$TMP"
  exit 2   # non-zero → Claude Code blocks the tool call, stderr shown to the model.
fi

rm -f "$TMP"
exit 0
