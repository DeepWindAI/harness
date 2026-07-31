#!/usr/bin/env bash
# check-sensitive-review.sh — is a PR safe to merge w.r.t. the sensitive-path review gate?
#
# Exit 0 = OK to merge (PR touches NO sensitive path, OR it does and carries a
#          review signal: an APPROVED GitHub review OR the `reviewed:code` label).
# Exit 1 = BLOCK (PR touches sensitive Agent Bridge / dispatch / auth paths and has
#          NEITHER an approving review NOR the reviewed:code label). Reason on stderr.
# Exit 2 = could not determine (gh error / no PR) — caller decides (advisory).
#
# Why this exists (free-plan reality): branch protection / required reviews are gated
# behind a paid GitHub plan for private repos, so the `sensitive-path-review-guard`
# CI check can only report, not block. This is the enforcement primitive the
# coordinator-side gate (scripts/git/guarded-merge.sh) and the pre-bash-merge-guard
# hook share. It cannot be cryptographic under single-account automation — a merger
# with rights can still add the label without reviewing — but it converts a SILENT
# self-merge (the PR #1045 failure: 34.6k lines, reviews=0) into a DELIBERATE, logged
# assertion that review happened. Pair with the code-reviewer workflow (CLAUDE.md #31).
set -euo pipefail

PR="${1:-}"
REPO="${2:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '')}"
[ -z "$PR" ] || [ -z "$REPO" ] && { echo "check-sensitive-review: missing PR/repo" >&2; exit 2; }

REVIEWED_LABEL='reviewed:code'

# Sensitive-path patterns are REPO-LOCAL policy (so this gate ships in the DeepWind
# harness bundle and each repo declares its OWN surfaces). One extended-regex per line,
# matched against PR file paths; '#' comments + blank lines ignored.
#
# CRITICAL — the policy is read from the TRUSTED BASE branch, NEVER from the PR head or
# the local working tree. If a PR could supply the policy that judges it, it could empty
# the file or strip its own protection lines and merge unreviewed — exactly the PR #1045
# self-weakening failure class this gate exists to stop (PR #1097 review, findings #1/#2).
# Resolution order: explicit override (testing only) → base-branch file via gh api →
# local origin/<base> → conservative generic default. Empty / all-comments is treated as
# "use the default", NEVER as "gate nothing" (fail-closed).
#
# A MANDATORY self-protection set (the gate's own machinery + the policy file itself) is
# ALWAYS unioned in, so no policy edit — in any repo, on any branch — can remove
# protection of the gate. Repos extend coverage via the file; they cannot subtract these.
DEFAULT_PATTERNS='^server/.*(auth|security)/
^server/middleware/auth
^.*/migrations/
^\.github/workflows/
^\.claude/hooks/'
MANDATORY_PATTERNS='^\.deepwind/sensitive-paths$
^\.github/workflows/sensitive-path-review-guard\.yml$
^\.claude/hooks/pre-bash-merge-guard\.sh$
^scripts/git/(check-sensitive-review|guarded-merge|agent-approve)\.sh$'

# Base branch of the PR (what the policy is trusted from). Default to main.
BASE=$(gh pr view "$PR" --repo "$REPO" --json baseRefName -q .baseRefName 2>/dev/null || echo main)
BASE=${BASE:-main}

# Emit the raw policy text from the trusted source. Always exits 0 (missing → empty).
raw_policy() {
  if [ -n "${DEEPWIND_SENSITIVE_PATHS:-}" ]; then
    # Explicit override — testing / non-git contexts only. Trusts the given file.
    cat "$DEEPWIND_SENSITIVE_PATHS" 2>/dev/null || true
    return 0
  fi
  # Base-branch committed policy via the API (independent of local fetch/checkout state).
  gh api "repos/$REPO/contents/.deepwind/sensitive-paths?ref=$BASE" \
    -H "Accept: application/vnd.github.raw" 2>/dev/null && return 0
  # Fallback: locally-tracked base ref.
  git show "origin/$BASE:.deepwind/sensitive-paths" 2>/dev/null || true
}

PATTERNS=$(raw_policy | grep -vE '^[[:space:]]*(#|$)' || true)
# Empty / all-comments base policy → conservative default (fail-closed, never exit 0).
if [ -z "$(printf '%s' "$PATTERNS" | tr -d '[:space:]')" ]; then
  PATTERNS="$DEFAULT_PATTERNS"
fi
# Union the non-removable mandatory set first so it can never be dropped by a policy edit.
PATTERNS=$(printf '%s\n%s\n' "$MANDATORY_PATTERNS" "$PATTERNS")

files=$(gh pr view "$PR" --repo "$REPO" --json files -q '.files[].path' 2>/dev/null) || { echo "check-sensitive-review: gh pr view failed for #$PR" >&2; exit 2; }
hits=$(printf '%s\n' "$files" | grep -Ef <(printf '%s\n' "$PATTERNS") || true)

if [ -z "$hits" ]; then
  exit 0   # not sensitive — nothing to gate
fi

approvals=$(gh pr view "$PR" --repo "$REPO" --json reviews -q '[.reviews[] | select(.state=="APPROVED")] | length' 2>/dev/null || echo 0)
has_label=$(gh pr view "$PR" --repo "$REPO" --json labels -q "[.labels[] | select(.name==\"$REVIEWED_LABEL\")] | length" 2>/dev/null || echo 0)

if [ "${approvals:-0}" -ge 1 ] || [ "${has_label:-0}" -ge 1 ]; then
  exit 0   # sensitive but reviewed
fi

{
  echo "BLOCKED: PR #$PR changes security-sensitive Agent Bridge / dispatch paths with no review signal:"
  printf '   %s\n' "$hits"
  echo "Required: an APPROVED GitHub review, or the '$REVIEWED_LABEL' label applied AFTER a code review."
  echo "Fix: dispatch pr-review-toolkit:code-reviewer; on an APPROVING verdict run"
  echo "     scripts/git/agent-approve.sh $PR <verdict-file>   (records the review + applies"
  echo "     '$REVIEWED_LABEL'; never hand-apply the label) then merge (see CLAUDE.md #31)."
} >&2
exit 1
