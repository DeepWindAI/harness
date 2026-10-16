#!/usr/bin/env bash
# shellcheck disable=SC2329
# ^ every "unused" function below is invoked indirectly: check_* functions are
# dispatched by NAME through run_check's "$fn", and cleanup runs via `trap … EXIT`.
# gate-doctor.sh — ADVISORY preflight for a merge-gate run. Predicts common,
# cheaply-detectable ways a gate dispatch for a pull request is about to waste
# its own time, in a few seconds, WITHOUT running the gate itself.
#
# CONTRACT: read-only on git (any refs it fetches for inspection go into a
# throwaway, PID-namespaced ref under refs/gate-doctor/tmp/*, deleted before
# exit — never a branch, the working tree, or an existing remote-tracking
# ref) and read-only on the forge (only read calls through `gh`). It never
# changes a gate verdict and is never a dependency of one: nothing in a real
# gate script should call this or fail if it is absent. It always exits 0
# unless --strict is given AND a check comes back WARN; a check that could
# not be evaluated prints "WARN could not determine (...)", never a crash
# and never a false PASS.
#
# Run it from inside the repository/branch you are about to gate (it reads
# the current working tree's git checkout — it does not need to live inside
# that repository).
#
# USAGE:
#   gate-doctor.sh <PR#> [--base <branch>] [--remote <name>] [--receipts-dir <path>] [--strict]
#
# CONFIGURATION (all optional — see docs/merge-gating.md):
#   --base / GATE_DOCTOR_BASE          base branch, default: the PR's own base
#                                       branch from `gh pr view`, else "main".
#   --remote / GATE_DOCTOR_REMOTE      git remote to fetch fresh refs from,
#                                       default: "origin".
#   --receipts-dir / GATE_DOCTOR_RECEIPTS_DIR
#                                       optional directory of prior gate
#                                       results (see "Recording receipts"
#                                       below). Skipped entirely if unset and
#                                       the default location does not exist.
#   --strict                           exit 1 if any check comes back WARN
#                                       (default: always exit 0 — advisory).
#
# RECORDING RECEIPTS (optional, opt-in): if your team records gate outcomes,
# drop one JSON file per attempt at
#   <receipts-dir>/<PR#>/<head-sha>.json
# containing at least {"result":"pass"} or {"result":"fail"}. gate-doctor
# warns when the most recent receipt at the PR's CURRENT head already failed,
# so a coordinator does not re-dispatch an expensive gate against unchanged
# code. Nothing else in this script writes to that directory.
set -uo pipefail

PR="${1:-}"
if ! [[ "$PR" =~ ^[1-9][0-9]*$ ]]; then
  echo "usage: gate-doctor.sh <PR#> [--base <branch>] [--remote <name>] [--receipts-dir <path>] [--strict]" >&2
  exit 2
fi
shift

BASE="${GATE_DOCTOR_BASE:-}"
REMOTE="${GATE_DOCTOR_REMOTE:-origin}"
RECEIPTS_DIR="${GATE_DOCTOR_RECEIPTS_DIR:-}"
STRICT=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --remote) REMOTE="${2:-}"; shift 2 ;;
    --receipts-dir) RECEIPTS_DIR="${2:-}"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    *) echo "gate-doctor: unknown argument: $1" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$REPO_ROOT" ]; then
  echo "gate-doctor: not inside a git working tree" >&2
  exit 2
fi

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/gate-doctor.XXXXXX")" || { echo "gate-doctor: could not create scratch dir" >&2; exit 1; }
TMP_REFS=()
cleanup() {
  local r
  for r in "${TMP_REFS[@]:-}"; do
    [ -n "$r" ] && git -C "$REPO_ROOT" update-ref -d "$r" >/dev/null 2>&1 || true
  done
  rm -rf "$WORKDIR" 2>/dev/null || true
}
trap cleanup EXIT

WARN_COUNT=0
REASONS=()

# Runs a check in a subshell so a crash inside it can never take gate-doctor
# down; forces any non-PASS/WARN first line, or a nonzero exit, to WARN.
run_check() {
  local num="$1" name="$2" fn="$3"
  local out rc first level rest
  out="$("$fn" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
    out="WARN could not determine (unexpected error, exit ${rc}${out:+: ${out}})"
  fi
  first="${out%%$'\n'*}"
  case "$first" in
    PASS\ *) level=PASS ;;
    WARN\ *) level=WARN ;;
    *) level=WARN; first="WARN could not determine (malformed check output: ${first:0:200})"; out="$first" ;;
  esac
  printf '[%s] %d. %-14s %s\n' "$level" "$num" "$name" "${first#* }"
  if [ "$out" != "$first" ]; then
    rest="${out#*$'\n'}"
    printf '%s\n' "$rest" | sed 's/^/      /'
  fi
  [ "$level" = WARN ] && { WARN_COUNT=$((WARN_COUNT + 1)); REASONS+=("$name"); }
}

# ── once-per-run resolution, shared by multiple checks ─────────────────────

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"

HEAD_SHA=""; BASE_REF_OID=""; PR_BASE_BRANCH=""
if [ -n "$REPO" ]; then
  PR_TSV="$(gh pr view "$PR" --repo "$REPO" --json headRefOid,baseRefOid,baseRefName \
    --jq '[.headRefOid,.baseRefOid,.baseRefName] | @tsv' 2>/dev/null || true)"
  [ -n "$PR_TSV" ] && IFS=$'\t' read -r HEAD_SHA BASE_REF_OID PR_BASE_BRANCH <<<"$PR_TSV"
fi
[ -z "$BASE" ] && BASE="${PR_BASE_BRANCH:-main}"

# Fresh base-branch tip and the PR's merge ref, each fetched into a
# throwaway, PID-namespaced ref (never an existing remote-tracking ref) so
# this can't collide with, or be starved by, other git activity in the repo.
FRESH_BASE_SHA=""; FRESH_BASE_TMP_REF="refs/gate-doctor/tmp/$$-base"
if git -C "$REPO_ROOT" fetch "$REMOTE" "+refs/heads/${BASE}:${FRESH_BASE_TMP_REF}" --quiet 2>/dev/null; then
  TMP_REFS+=("$FRESH_BASE_TMP_REF")
  FRESH_BASE_SHA="$(git -C "$REPO_ROOT" rev-parse "$FRESH_BASE_TMP_REF" 2>/dev/null || true)"
fi

PR_MERGE_SHA=""; PR_MERGE_TMP_REF="refs/gate-doctor/tmp/$$-pr-$PR-merge"
if git -C "$REPO_ROOT" fetch "$REMOTE" "+refs/pull/$PR/merge:${PR_MERGE_TMP_REF}" --quiet 2>/dev/null; then
  TMP_REFS+=("$PR_MERGE_TMP_REF")
  PR_MERGE_SHA="$(git -C "$REPO_ROOT" rev-parse "$PR_MERGE_TMP_REF" 2>/dev/null || true)"
fi

[ -z "$RECEIPTS_DIR" ] && RECEIPTS_DIR="$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null)/gate-doctor-receipts"
case "$RECEIPTS_DIR" in /*) ;; *) RECEIPTS_DIR="$REPO_ROOT/$RECEIPTS_DIR" ;; esac

# ── checks ───────────────────────────────────────────────────────────────

# 1. Base branch is fresh: pin the judge — a gate that runs against a base
# the PR hasn't caught up to is judging the wrong tree.
check_stale_base() {
  [ -z "${HEAD_SHA:-}" ] && { echo "WARN could not determine (missing PR head sha — is 'gh' authenticated?)"; return 0; }
  [ -z "${FRESH_BASE_SHA:-}" ] && { echo "WARN could not determine (could not fetch a fresh $REMOTE/$BASE)"; return 0; }
  if git -C "$REPO_ROOT" merge-base --is-ancestor "$FRESH_BASE_SHA" "$HEAD_SHA" 2>/dev/null; then
    echo "PASS fresh $REMOTE/$BASE ($FRESH_BASE_SHA) is an ancestor of the PR head"
  else
    echo "WARN PR head does not contain the latest $REMOTE/$BASE ($FRESH_BASE_SHA) — merge or rebase before an expensive gate run, or it will judge a tree main has already moved past"
  fi
}

# 2. The forge's own merge preview agrees with the base it says it used —
# catches a stale merge-ref build after a fast-moving base branch.
check_merge_ref() {
  [ -z "${BASE_REF_OID:-}" ] && { echo "WARN could not determine (missing baseRefOid from 'gh pr view')"; return 0; }
  [ -z "${FRESH_BASE_SHA:-}" ] && { echo "WARN could not determine (could not fetch a fresh $REMOTE/$BASE)"; return 0; }
  [ -z "${PR_MERGE_SHA:-}" ] && { echo "WARN could not determine (refs/pull/$PR/merge not fetchable — conflicts, or the forge has not built it yet)"; return 0; }
  local parent1
  parent1="$(git -C "$REPO_ROOT" rev-parse "${PR_MERGE_SHA}^1" 2>/dev/null || true)"
  [ -z "$parent1" ] && { echo "WARN could not determine (could not resolve refs/pull/$PR/merge^1)"; return 0; }
  if [ "$parent1" = "$BASE_REF_OID" ] && [ "$BASE_REF_OID" = "$FRESH_BASE_SHA" ]; then
    echo "PASS merge-ref parent, recorded base, and live $BASE all agree ($BASE_REF_OID)"
  else
    echo "WARN merge ref out of sync — merge-parent=$parent1 recorded-base=$BASE_REF_OID live-$BASE=$FRESH_BASE_SHA; close+reopen or push to refresh the forge's preview"
  fi
}

# 3. Prior receipt at this EXACT head already failed — do not re-dispatch
# an expensive gate against code that has not changed since.
check_prior_red() {
  [ -z "${HEAD_SHA:-}" ] && { echo "WARN could not determine (missing PR head sha)"; return 0; }
  [ ! -d "$RECEIPTS_DIR/$PR" ] && { echo "PASS no receipts recorded for PR #$PR (receipts dir: $RECEIPTS_DIR)"; return 0; }
  local receipt="$RECEIPTS_DIR/$PR/$HEAD_SHA.json"
  [ ! -f "$receipt" ] && { echo "PASS no receipt recorded at head $HEAD_SHA"; return 0; }
  if command -v jq >/dev/null 2>&1; then
    local result
    result="$(jq -r '.result // "unknown"' "$receipt" 2>/dev/null || echo unknown)"
    case "$result" in
      pass) echo "PASS prior receipt at this head passed" ;;
      fail) echo "WARN prior receipt at this exact head FAILED ($receipt) — fix the defect, don't just re-dispatch unchanged code" ;;
      *) echo "WARN could not determine (receipt at $receipt has no usable \"result\" field)" ;;
    esac
  else
    echo "WARN could not determine (a receipt exists at $receipt but 'jq' is unavailable to read it)"
  fi
}

# 4. Deletions reminder: a bulk delete is exactly the kind of change a
# reviewer or gate can wave through without noticing scope.
check_deletions() {
  [ -z "${HEAD_SHA:-}" ] || [ -z "${FRESH_BASE_SHA:-}" ] && { echo "WARN could not determine (missing head or fresh-base sha)"; return 0; }
  local deleted rc
  deleted="$(git -C "$REPO_ROOT" diff --diff-filter=D --name-only "${FRESH_BASE_SHA}...${HEAD_SHA}" 2>/dev/null)"
  rc=$?
  [ "$rc" -ne 0 ] && { echo "WARN could not determine (git diff --diff-filter=D failed)"; return 0; }
  if [ -z "$deleted" ]; then
    echo "PASS no file deletions relative to $BASE"
  else
    local n
    n="$(printf '%s\n' "$deleted" | grep -c .)"
    echo "WARN this PR deletes ${n} file(s) — confirm they are intentional in the PR description before gating; a gate/reviewer checking diff stats alone can miss a deletion hiding in a large changeset"
  fi
}

# ── run ──────────────────────────────────────────────────────────────────

echo "gate-doctor: PR #$PR${REPO:+ ($REPO)} — advisory only, changes no verdict, not required by any gate"
echo

run_check 1 "stale-base"  check_stale_base
run_check 2 "merge-ref"   check_merge_ref
run_check 3 "prior-red"   check_prior_red
run_check 4 "deletions"   check_deletions

echo
if [ "$WARN_COUNT" -gt 0 ]; then
  echo "PREDICTED OUTCOME: ${WARN_COUNT} check(s) could not confirm a clean gate (${REASONS[*]})"
  [ "$STRICT" -eq 1 ] && exit 1
else
  echo "PREDICTED OUTCOME: likely green — all checks passed"
fi
exit 0
