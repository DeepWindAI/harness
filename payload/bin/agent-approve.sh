#!/usr/bin/env bash
# agent-approve.sh — record a SEPARATE specialist agent's code review as the merge
# signal for a sensitive PR, so the `reviewed:code` label is never a bare self-
# assertion. Posts the reviewer's verdict to the PR as an evidence comment AND
# applies the label (which scripts/git/check-sensitive-review.sh requires to merge).
#
# Independence model (free plan, no CI/branch-protection): the reviewer is a
# distinct pr-review-toolkit:code-reviewer specialist agent, NOT the coordinator that
# wrote the code and NOT a human. This script ties the label to that review's actual
# output so every sensitive merge carries the specialist's findings on the PR.
# It is NOT cryptographic — a coordinator with merge rights can still fabricate a
# verdict — but it makes "a separate specialist reviewed this" auditable and refuses
# to label a non-approving verdict.
#
# Usage (run ONLY after dispatching pr-review-toolkit:code-reviewer, on APPROVE):
#   scripts/git/agent-approve.sh <PR#> path/to/verdict.txt     # verdict from a file
#   scripts/git/agent-approve.sh <PR#> < verdict.txt           # or from stdin
#
# Refuses (exit 1) on an empty verdict, a DO-NOT-MERGE / changes-requested verdict,
# or a verdict lacking any APPROVE/MERGE signal. See CLAUDE.md #31.
set -euo pipefail

PR="${1:-}"
[ -z "$PR" ] && { echo "usage: $0 <PR#> [verdict-file]   (verdict on stdin if no file)" >&2; exit 2; }

if [ -n "${2:-}" ]; then
  [ -r "$2" ] || { echo "agent-approve: cannot read verdict file '$2'" >&2; exit 2; }
  VERDICT=$(cat "$2")
else
  VERDICT=$(cat)   # stdin
fi

# Non-empty?
if [ -z "$(printf '%s' "$VERDICT" | tr -d '[:space:]')" ]; then
  echo "agent-approve: empty verdict — a separate specialist review is required before labeling." >&2
  exit 1
fi

# Decide from the HEADLINE (first non-empty line) only, NOT the full prose. A thorough
# review body discusses reject cases ("do not merge", "changes requested") in its analysis,
# so scanning the whole text false-refuses genuine approvals (PR #1073 review, finding I1).
# The caller must LEAD the verdict with the reviewer's recommendation, e.g.
# "APPROVED — safe to merge" or "DO-NOT-MERGE — <reason>". The full body is still posted as
# evidence below.
HEADLINE=$(printf '%s\n' "$VERDICT" | grep -m1 -vE '^[[:space:]]*$' || true)

# Reject only on UNAMBIGUOUS decision phrases (these do not appear in an approval headline).
if printf '%s' "$HEADLINE" | grep -qiE 'do[[:space:]_-]*not[[:space:]_-]*(merge|approve)|\breject(ed)?\b'; then
  echo "agent-approve: headline verdict is a rejection — refusing to label PR #$PR." >&2
  exit 1
fi
# …and the headline MUST carry an approval signal.
if ! printf '%s' "$HEADLINE" | grep -qiE '\bMERGE\b|\bAPPROVED?\b|\bLGTM\b'; then
  echo "agent-approve: no APPROVE/MERGE signal on the headline verdict — refusing to label PR #$PR." >&2
  echo "  Lead the verdict with the reviewer's recommendation, e.g. 'APPROVED — safe to merge'." >&2
  exit 1
fi

# Dry-run: run the guards + decision only, make NO GitHub mutation. For testing/preview.
if [ "${AGENT_APPROVE_DRYRUN:-0}" = "1" ]; then
  echo "agent-approve: DRY RUN — guards passed; would post evidence + apply 'reviewed:code' to PR #$PR."
  exit 0
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
BODY=$(printf '🤖 **Specialist agent code review** (`pr-review-toolkit:code-reviewer`) — recorded as the `reviewed:code` merge-gate signal (CLAUDE.md #31).\n\n---\n\n%s' "$VERDICT")

gh pr comment "$PR" --repo "$REPO" --body "$BODY" >/dev/null
gh pr edit  "$PR" --repo "$REPO" --add-label 'reviewed:code' >/dev/null
echo "agent-approve: posted specialist-review evidence + applied 'reviewed:code' on PR #$PR."
