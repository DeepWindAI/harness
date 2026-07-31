#!/usr/bin/env bash
# guarded-merge.sh — the sanctioned way to merge a PR. Refuses to merge a PR that
# touches security-sensitive Agent Bridge / dispatch / auth paths unless it carries
# a review signal (see check-sensitive-review.sh). Portable — works for ANY
# automation (Claude, codex, human), including where the pre-bash-merge-guard hook
# does not apply (non-Claude coordinators).
#
# Usage:  scripts/git/guarded-merge.sh <PR#> [extra gh pr merge args...]
#   e.g.  scripts/git/guarded-merge.sh 1234 --squash --delete-branch
#
# On a sensitive+unreviewed PR it exits 1 and merges NOTHING. Otherwise it execs
# `gh pr merge <PR#> <args>` (default args: --squash --delete-branch).
set -euo pipefail

PR="${1:-}"
[ -z "$PR" ] && { echo "usage: $0 <PR#> [gh pr merge args...]" >&2; exit 2; }
shift

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$DIR/check-sensitive-review.sh"

if [ -x "$CHECK" ]; then
  set +e
  "$CHECK" "$PR"
  rc=$?
  set -e
  if [ "$rc" -eq 1 ]; then
    echo "guarded-merge: refusing to merge PR #$PR — review the sensitive change first." >&2
    exit 1
  fi
  # rc 2 (undeterminable) is advisory — fall through and let gh surface any real error.
fi

if [ "$#" -eq 0 ]; then
  set -- --squash --delete-branch
fi
echo "guarded-merge: merging PR #$PR ($*)"
exec gh pr merge "$PR" "$@"
