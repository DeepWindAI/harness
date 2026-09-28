#!/usr/bin/env bash
# Fixture tests for payload/bin/gate-doctor.sh. Builds a local bare "origin"
# repository (no network) plus a fake `gh` on PATH, and exercises every check
# gate-doctor.sh performs: fresh-base, merge-ref sync, prior-receipt, and
# deletions. No real GitHub or DeepWind repository is touched.
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
DOCTOR="$ROOT/payload/bin/gate-doctor.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/deepwind-gate-doctor-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -x "$DOCTOR" ] || fail 'payload/bin/gate-doctor.sh is missing or not executable'

# ---- fake `gh`: no network, no real forge. Reads its canned answers from
# env vars so each scenario below can steer it without touching the script. --
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'FAKE_GH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-} ${2:-}" in
  "repo view")
    printf '%s\n' "${FAKE_GH_REPO:-test-org/test-repo}"
    ;;
  "pr view")
    printf '%s\t%s\t%s\n' "${FAKE_GH_HEAD_SHA:?}" "${FAKE_GH_BASE_SHA:?}" "${FAKE_GH_BASE_BRANCH:-main}"
    ;;
  *)
    echo "fake gh: unexpected invocation: $*" >&2
    exit 91
    ;;
esac
FAKE_GH
chmod 755 "$TMP/bin/gh"
export PATH="$TMP/bin:$PATH"

# ---- fixture repo + bare "origin" (all local; git fetch works over a plain
# filesystem path, so no server or network is needed). ----------------------
ORIGIN="$TMP/origin.git"
WORK="$TMP/work"
git init --quiet --bare "$ORIGIN"
git init --quiet "$WORK"
git -C "$WORK" config user.email test@example.com
git -C "$WORK" config user.name "Gate Doctor Test"
git -C "$WORK" remote add origin "$ORIGIN"

git -C "$WORK" checkout --quiet -b main
echo "base" > "$WORK/base.txt"
echo "keep-me" > "$WORK/kept.txt"
git -C "$WORK" add base.txt kept.txt
git -C "$WORK" commit --quiet -m "base commit"
git -C "$WORK" push --quiet origin main
BASE_SHA=$(git -C "$WORK" rev-parse main)

git -C "$WORK" checkout --quiet -b pr-branch
echo "head" > "$WORK/head.txt"
git -C "$WORK" add head.txt
git -C "$WORK" commit --quiet -m "PR commit"
HEAD_SHA=$(git -C "$WORK" rev-parse pr-branch)

# Publish refs/pull/42/{head,merge} on "origin", the way a forge would, via a
# real merge commit — parent 1 is the recorded base, parent 2 is the head.
git -C "$WORK" push --quiet origin "pr-branch:refs/pull/42/head"
MERGE_SHA=$(git -C "$WORK" -c user.email=test@example.com -c user.name="Gate Doctor Test" \
  commit-tree "$(git -C "$WORK" rev-parse "pr-branch^{tree}")" -p "$BASE_SHA" -p "$HEAD_SHA" \
  -m "merge preview")
git -C "$WORK" push --quiet origin "$MERGE_SHA:refs/pull/42/merge"

run_doctor() {
  ( cd "$WORK" && FAKE_GH_REPO="test-org/test-repo" FAKE_GH_HEAD_SHA="$HEAD_SHA" \
    FAKE_GH_BASE_SHA="$BASE_SHA" FAKE_GH_BASE_BRANCH="main" \
    "$DOCTOR" "$@" )
}

# ---- 1. Clean PR: base fresh, merge-ref in sync, no receipts, no deletions.
out=$(run_doctor 42 --remote origin)
rc=$?
[ "$rc" -eq 0 ] || fail "clean PR: gate-doctor exited $rc, expected 0"
echo "$out" | grep -q '^\[PASS\] 1\. stale-base' || fail 'clean PR: stale-base did not PASS'
echo "$out" | grep -q '^\[PASS\] 2\. merge-ref' || fail 'clean PR: merge-ref did not PASS'
echo "$out" | grep -q '^\[PASS\] 3\. prior-red' || fail 'clean PR: prior-red did not PASS'
echo "$out" | grep -q '^\[PASS\] 4\. deletions' || fail 'clean PR: deletions did not PASS'
echo "$out" | grep -q 'PREDICTED OUTCOME: likely green' || fail 'clean PR: missing likely-green verdict'

# ---- 2. Stale base: origin/main moves on without the PR rebasing onto it.
git -C "$WORK" checkout --quiet main
echo "unrelated" > "$WORK/unrelated.txt"
git -C "$WORK" add unrelated.txt
git -C "$WORK" commit --quiet -m "main moved on"
git -C "$WORK" push --quiet origin main
git -C "$WORK" checkout --quiet pr-branch

out=$(run_doctor 42 --remote origin --strict) && rc=0 || rc=$?
[ "$rc" -eq 1 ] || fail "stale base: --strict exited $rc, expected 1"
echo "$out" | grep -q '^\[WARN\] 1\. stale-base' || fail 'stale base: stale-base did not WARN'
echo "$out" | grep -q '^\[WARN\] 2\. merge-ref' || fail 'stale base: merge-ref did not WARN (baseRefOid vs live main)'
echo "$out" | grep -q 'PREDICTED OUTCOME:.*stale-base' || fail 'stale base: verdict does not name stale-base'

# Non-strict mode never fails the exit code, only the printed verdict.
out=$(run_doctor 42 --remote origin) && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail 'stale base: non-strict mode must still exit 0'
echo "$out" | grep -q '^\[WARN\] 1\. stale-base' || fail 'stale base (non-strict): stale-base did not WARN'

# Reset origin/main back to the PASS fixture for the remaining scenarios.
git -C "$ORIGIN" update-ref refs/heads/main "$BASE_SHA"

# ---- 3. Prior receipt at this exact head already failed.
RECEIPTS="$TMP/receipts"
mkdir -p "$RECEIPTS/42"
printf '{"result":"fail","note":"fixture"}\n' > "$RECEIPTS/42/$HEAD_SHA.json"
out=$(run_doctor 42 --remote origin --receipts-dir "$RECEIPTS")
echo "$out" | grep -q '^\[WARN\] 3\. prior-red' || fail 'prior receipt: prior-red did not WARN on a recorded failure'
echo "$out" | grep -qi 'FAILED' || fail 'prior receipt: WARN message does not mention the failure'

printf '{"result":"pass"}\n' > "$RECEIPTS/42/$HEAD_SHA.json"
out=$(run_doctor 42 --remote origin --receipts-dir "$RECEIPTS")
echo "$out" | grep -q '^\[PASS\] 3\. prior-red' || fail 'prior receipt: a passing receipt must PASS'

# GATE_DOCTOR_RECEIPTS_DIR env var is equivalent to --receipts-dir.
printf '{"result":"fail"}\n' > "$RECEIPTS/42/$HEAD_SHA.json"
out=$(cd "$WORK" && FAKE_GH_REPO="test-org/test-repo" FAKE_GH_HEAD_SHA="$HEAD_SHA" \
  FAKE_GH_BASE_SHA="$BASE_SHA" FAKE_GH_BASE_BRANCH="main" \
  GATE_DOCTOR_RECEIPTS_DIR="$RECEIPTS" "$DOCTOR" 42 --remote origin)
echo "$out" | grep -q '^\[WARN\] 3\. prior-red' || fail 'GATE_DOCTOR_RECEIPTS_DIR env var was not honored'

# ---- 4. Deletions: a follow-up commit on the PR branch removes a base file.
git -C "$WORK" checkout --quiet pr-branch
git -C "$WORK" rm --quiet kept.txt
git -C "$WORK" commit --quiet -m "drop kept.txt"
HEAD_SHA_WITH_DELETE=$(git -C "$WORK" rev-parse pr-branch)
git -C "$WORK" push --quiet --force origin "pr-branch:refs/pull/42/head"
DEL_MERGE_SHA=$(git -C "$WORK" -c user.email=test@example.com -c user.name="Gate Doctor Test" \
  commit-tree "$(git -C "$WORK" rev-parse "pr-branch^{tree}")" -p "$BASE_SHA" -p "$HEAD_SHA_WITH_DELETE" \
  -m "merge preview 2")
git -C "$WORK" push --quiet --force origin "$DEL_MERGE_SHA:refs/pull/42/merge"

out=$(cd "$WORK" && FAKE_GH_REPO="test-org/test-repo" FAKE_GH_HEAD_SHA="$HEAD_SHA_WITH_DELETE" \
  FAKE_GH_BASE_SHA="$BASE_SHA" FAKE_GH_BASE_BRANCH="main" "$DOCTOR" 42 --remote origin)
echo "$out" | grep -q '^\[WARN\] 4\. deletions' || fail 'deletions: expected a WARN when the PR deletes a file'
echo "$out" | grep -q '1 file(s)' || fail 'deletions: expected the deletion count in the WARN message'

# ---- 5. No PR resolvable (gh fails outright) degrades to WARN, never crashes,
# and never fails the exit code unless --strict is given.
cat > "$TMP/bin/gh" <<'FAKE_GH_DOWN'
#!/usr/bin/env bash
exit 17
FAKE_GH_DOWN
chmod 755 "$TMP/bin/gh"
out=$(cd "$WORK" && "$DOCTOR" 42 --remote origin) && rc=0 || rc=$?
[ "$rc" -eq 0 ] || fail "gh unavailable: non-strict run exited $rc, expected 0"
echo "$out" | grep -q 'could not determine' || fail 'gh unavailable: expected a "could not determine" WARN, not a crash'

# ---- 6. Basic usage/argument errors ----------------------------------------
"$DOCTOR" >/dev/null 2>&1 && fail 'missing PR argument should exit non-zero'
"$DOCTOR" not-a-number >/dev/null 2>&1 && fail 'non-numeric PR argument should exit non-zero'
"$DOCTOR" 42 --bogus-flag >/dev/null 2>&1 && fail 'unknown flag should exit non-zero'

printf 'PASS: gate-doctor.sh preflight tests\n'
