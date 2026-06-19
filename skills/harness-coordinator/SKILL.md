---
name: harness-coordinator
description: Use when the user wants to coordinate, resume, or execute a multi-session harness project — phrases like "coordinate this harness", "resume as coordinator", "run this harness", "manage harness work". Orchestrates specialists across sessions, manages worktree isolation for parallel agents, tracks progress, enforces quality gates. Coordinator delegates ALL implementation via Task tool — never writes code directly.
---

# Harness Coordinator

**Role**: Project orchestrator. You coordinate specialists, you do NOT implement code yourself.

**Reusable on any repository.** Bundled portable scripts live at `~/.claude/skills/harness-coordinator/scripts/`. Artifact paths default to `.harness/` and can be overridden via `HARNESS_ARTIFACTS_ROOT`.

---

## When to use

- Managing a harness project in `.harness/projects/<slug>/` (or `$HARNESS_ARTIFACTS_ROOT/projects/<slug>/`)
- Multi-session work, typically 16+ hours and 3+ sessions
- Multiple specialists needed (backend, frontend, database, etc.)
- User says "coordinate this harness" / "resume as coordinator" / "run this harness"

**Do NOT use for**:
- Single-session features under ~8 hours
- Writing code yourself (delegate to specialists)
- Debugging or testing yourself (specialists handle this)
- Harness planning (use `harness-planner` first; coordinator executes an already-approved plan)

---

## Critical role boundaries

**YOU DO NOT**:
- ❌ Read implementation files (`src/**`, `app/**`, `*.ts`, `*.tsx`, etc.)
- ❌ Write or edit ANY code files
- ❌ Implement features yourself
- ❌ Debug or fix code issues yourself
- ❌ Run tests or validation scripts yourself
- ❌ Make git commits for FEATURE code (delegate to specialists in their worktree)

**YOU DO**:
- ✅ Read coordination artifacts (`progress.json`, `session-log.txt`, `README.md`)
- ✅ Run `init.sh` to verify environment (once per session)
- ✅ Use `jq` to query progress files
- ✅ Use Task tool to launch specialists, instructing them to load `harness-discipline`
- ✅ Update `progress.json` after specialists report completion
- ✅ Append to `session-log.txt` after each session
- ✅ Merge specialist branches back into the harness branch after each wave (sequential coordinator action)
- ✅ Open and shepherd the harness PR at the end

If you find yourself reaching for the Edit / Write tool on a code file, STOP — dispatch a specialist instead.

---

## The harness worktree (MANDATORY)

Each harness runs in its own git worktree on a dedicated local branch named `harness/<HARNESS_ID>`. This is the isolation: every harness has its own working tree, its own branch, its own files-on-disk. Multiple harnesses can run in parallel because they never share a working tree.

### Provision at session start

```bash
HARNESS_ID="<your-slug>"           # e.g., contact-form-ux-001
MAIN="$(git rev-parse --git-common-dir | sed 's,/\.git$,,')"
WORKTREE="$MAIN/.claude/worktrees/harness-${HARNESS_ID}"

# Create worktree + local branch (idempotent — skips if already exists)
if [ ! -d "$WORKTREE" ]; then
  git worktree add -b "harness/${HARNESS_ID}" "$WORKTREE" HEAD
fi

cd "$WORKTREE"
export CLAUDE_AGENT_ID="$HARNESS_ID"
```

If the planner dropped artifacts in the main worktree (`.harness/projects/<HARNESS_ID>/`), copy them into the harness worktree on first entry, then commit:

```bash
ARTIFACTS_ROOT="${HARNESS_ARTIFACTS_ROOT:-.harness}"
DIR="$ARTIFACTS_ROOT/projects/${HARNESS_ID}"
if [ ! -d "$DIR" ] && [ -d "$MAIN/$DIR" ]; then
  mkdir -p "$(dirname "$DIR")"
  cp -r "$MAIN/$DIR" "$(dirname "$DIR")/"
  git add "$DIR/" && git commit -m "chore(${HARNESS_ID}): scaffold plan artifacts"
fi
```

Skip both steps if you're already inside `.claude/worktrees/harness-*`.

The branch stays local until PR time. Optional mid-harness safety push: `git push -u origin harness/${HARNESS_ID}` — no PR opens until you explicitly create one.

### Parallel harnesses

Different harness IDs → different worktrees → no contention. **One coordinator per harness, ever.** If two coordinators try to run the same harness concurrently, you have a planning failure, not a coordination failure.

---

## Coordination workflow per session

### Phase 1 — Session startup (5 min)

```bash
ARTIFACTS_ROOT="${HARNESS_ARTIFACTS_ROOT:-.harness}"
PROJECT_DIR="$ARTIFACTS_ROOT/projects/${HARNESS_ID}"

# Run init.sh — verifies dependencies, lockfile, type baseline, lint baseline
bash "$PROJECT_DIR/init.sh"

# Find the next pending feature
jq '.project.phases[].features[] | select(.status == "pending")' "$PROJECT_DIR/progress.json" | head -50

# Read the most recent sessions
tail -150 "$PROJECT_DIR/session-log.txt"

# Recent commits on this harness
git log --oneline -10 --grep="FEAT-"
```

### Phase 2 — Specialist selection (2 min)

Pick the specialist that matches the feature's `specialist` field in `progress.json`. The planner already made this decision; you just dispatch.

| Field value | Subagent type |
|---|---|
| `backend-architect` | `backend-architect` |
| `frontend-developer` | `frontend-developer` |
| `database-admin` | `database-admin` |
| `security-auditor` | `security-auditor` |
| `ai-engineer` | `ai-engineer` |
| `performance-engineer` | `performance-engineer` |
| `test-automator` | `test-automator` |
| `api-documenter` | `api-documenter` |
| `ui-ux-designer` | `ui-ux-designer` |
| `general-purpose` | `general-purpose` |

Set the `model` parameter on the Task call to match the feature's `llmTier` (`haiku` / `sonnet` / `opus`).

### Phase 3 — Launch specialist

For SERIAL waves (one specialist at a time) the harness worktree is sufficient — every specialist works in your `$WORKTREE`.

For PARALLEL waves (2+ specialists in the same coordinator message) spawn per-agent sub-worktrees BEFORE the Task calls — see "Parallel agents" below.

Every specialist Task prompt MUST start with this preamble:

```
**Working directory**: <full path to harness worktree, OR per-agent worktree if parallel>
**Branch**: harness/<HARNESS_ID>   (or worktree-agent-<AGENT_ID> if parallel)
**Agent ID**: <HARNESS_ID>-<feature-id>-<specialist>
**Required skill to load first**: Skill({ skill: "harness-discipline" })
**Run before any git or file op**:
  cd <working directory>
  export CLAUDE_AGENT_ID=<agent-id>

**MANDATORY FIRST ACTION** (harness-discipline Phase 0): verify your environment
matches the three values above (working directory, branch, agent ID) before
running ANY other command. If anything mismatches — especially if `git branch
--show-current` returns `main`, `master`, `staging`, `production`, or a
`release-*` branch — STOP and report back. Do not attempt to `git checkout` or
`cd` yourself out of the mismatch; that indicates the dispatch broke and the
coordinator needs to re-issue. The FEAT-0.2 commit-to-main incident
(2026-06-19) happened because a specialist skipped this verification.

You have been dispatched to implement feature <FEAT-ID> in harness <HARNESS_ID>.
Specification is in <PROJECT_DIR>/progress.json — find the feature by ID.
Follow the TDD cycle from harness-discipline: RED → GREEN → REFACTOR → DELIVERY.
Update progress.json and session-log.txt when complete.
Commit FROM YOUR WORKTREE with explicit file paths.
Report back with evidence: test results, commit SHA.
```

The `Skill({ skill: "harness-discipline" })` load is mandatory for the specialist — it gives them the TDD cycle, progress-tracking format, escalation protocol, and reporting template.

### Phase 4 — Monitor & handle issues

**If specialist reports completion:** verify, update tracking, dispatch next feature.

**If specialist reports a blocker:**
- **Technical (missing dep, unclear req)** → ask user, defer feature
- **Quality gate failure** → dispatch debugger / test-automator to investigate; don't fix yourself
- **Architectural decision needed** → escalate to user, document in README
- **Discovered scope expansion** → document the issue, dispatch architect / DBA / security review to scope it, update plan, then resume

### Phase 4.5 — Update progress.json safely

When marking a feature done in `progress.json` or appending a session entry to
`session-log.txt`, do NOT use plain `git add . && git commit`. Use the wrapper:

```bash
bash ~/.claude/skills/harness-coordinator/scripts/coordinator-update-progress.sh \
  "$PROJECT_DIR" \
  "chore(${HARNESS_ID}): mark FEAT-X.Y completed"
```

The wrapper:
- refuses to commit if HEAD is on `main`/`master`/`staging`/`production`/`release-*`
- refuses to commit if there are uncommitted files **outside** the project dir
  (those would be silently absorbed into the progress commit — the 2026-06-19
  Phase 1 reversion class)
- stages only `progress.json` + `session-log.txt`
- verifies the new commit's parent is exactly the pre-commit HEAD (no rewrite)

If the wrapper aborts, the worktree is telling you something — investigate
before forcing.

### Phase 5 — Verify completion (5 min)

```bash
# Feature status changed?
jq ".project.phases[].features[] | select(.id == \"FEAT-X.Y\")" "$PROJECT_DIR/progress.json"

# Git commit exists?
git log -1 --grep="FEAT-X.Y"

# Append session entry
{
  echo ""
  echo "=== Session $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "Completed: FEAT-X.Y"
  echo "Specialist: <type> on <tier>"
  echo "Commit: $(git log -1 --grep='FEAT-X.Y' --format='%h')"
} >> "$PROJECT_DIR/session-log.txt"
```

---

## Parallel agents — worktree isolation

When you launch 2+ Task calls in the same coordinator message, each specialist needs its own per-agent worktree. Without this, two `git add` windows can overlap and one specialist's files get absorbed into the other's commit. Per-agent worktrees give each specialist its own git index — `git add .` only sees that worktree's files.

### Pre-launch — spawn a worktree per parallel specialist

```bash
# Use stable agent IDs (slug-style) so they survive session restarts
bash ~/.claude/skills/harness-coordinator/scripts/spawn-worktree.sh "feat-007-backend"
bash ~/.claude/skills/harness-coordinator/scripts/spawn-worktree.sh "feat-007-frontend"
# Each script prints the worktree path it created.
```

Agent ID rules: 4–32 chars, `[a-zA-Z0-9_-]` only. The script is idempotent.

Pass the worktree path + agent ID to each specialist Task prompt (see preamble above).

### End-of-wave merge (coordinator responsibility)

After all parallel specialists confirm clean commits, the COORDINATOR merges sequentially from the harness worktree.

**Pre-merge dirty-tree guard** — refuses to merge if the receiving worktree has uncommitted changes (those would be absorbed into the merge commit, a silent class of error that's hard to detect later).

```bash
# Pre-merge guard
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ABORT: worktree is dirty — would absorb uncommitted work." >&2
  git status --short >&2
  exit 1
fi

# Merge each specialist branch with the explicit-staging wrapper
bash ~/.claude/skills/harness-coordinator/scripts/coordinator-merge.sh \
  worktree-agent-feat-007-backend "merge(wave-N): backend specialist work"

bash ~/.claude/skills/harness-coordinator/scripts/coordinator-merge.sh \
  worktree-agent-feat-007-frontend "merge(wave-N): frontend specialist work"
```

Use `coordinator-merge.sh`, NOT raw `git merge`. The wrapper closes a silent-file-drop class where default 3-way merge can lose ADDs from the merged branch when any conflict elsewhere triggers fallback. It explicitly stages every file the merged branch touched.

On conflict the wrapper saves state and prompts you to resolve manually, then run `coordinator-merge.sh --continue`.

### Cleanup after merge

```bash
bash ~/.claude/skills/harness-coordinator/scripts/cleanup-worktree.sh "feat-007-backend"
bash ~/.claude/skills/harness-coordinator/scripts/cleanup-worktree.sh "feat-007-frontend"
```

The script refuses if the branch has unmerged commits unless you pass `--force`. If it refuses, something was not merged — investigate before forcing.

### When NOT to use parallel agents

If features depend on each other sequentially (each one's `dependencies` array references a sibling in the same wave), don't parallelize — dispatch them one at a time. The dependency graph in `progress.json` tells you which features can run together.

---

## Before diagnosing absorption — run the diagnostic first

If `git diff <base>..HEAD` on the harness branch shows hundreds of files / thousands of lines and your first instinct is "cross-agent absorption" — pause. The diff might be showing the SET UNION of (a) files YOUR commits changed + (b) files that landed on `<base>` during your harness run. `git diff base..HEAD` does NOT distinguish these.

Quick diagnostic:

```bash
BASE="${1:-origin/main}"
MERGE_BASE="$(git merge-base "$BASE" HEAD)"

# Files OUR commits actually touched
OUR_FILES=$(git diff --name-only "$MERGE_BASE..HEAD" | wc -l)
# Files base advanced through that we did NOT touch
BASE_FILES=$(git diff --name-only "$MERGE_BASE..$BASE" | wc -l)
# Naive diff count (what people quote when panicking)
NAIVE=$(git diff --name-only "$BASE..HEAD" | wc -l)

echo "Files OUR commits touched:    $OUR_FILES"
echo "Files BASE advanced through:  $BASE_FILES"
echo "Naive 'git diff' file count:  $NAIVE   (= our touches + base advances)"
```

If `OUR_FILES` is small and `BASE_FILES` is large, the verdict is CLEAN — base just moved during your run. Recovery is `git fetch origin && git rebase $BASE`, not cherry-pick or filter. The diagnostic takes 30 seconds and prevents recommending destructive recovery for a normal rebase scenario.

---

## Resource management — test runner serialization

When specialists run tests, give them clear instructions on test serialization. The general rule:

- **One specialist runs tests at a time.** Concurrent test runs from multiple specialists can spawn many worker processes per run × multiple runs = system overload.
- **Use the repo's serialized test command if one exists.** Look for scripts named `test:locked`, `test:serial`, `test:ci`, or a file-lock wrapper. If the repo has one, mandate it in the Task prompt.
- **If no serialized command exists**, add this rule to the specialist prompt:

```
**Before running tests**: check `ps aux | grep -E "vitest|jest|pytest" | grep -v grep | wc -l`
If >0 test processes are running, wait until they complete.
Do not run validations in parallel (no &). Use sequential && chaining:
  <type-check> && <test> && <lint>
```

### Diagnostic typecheck orphans (TypeScript-specific; analogous patterns elsewhere)

**TypeScript/JavaScript projects**: if your specialists run diagnostic `npx tsc --noEmit` calls during debugging, those leave `tsc --build` worker processes behind that aren't `vitest`/`jest` and aren't covered by test-process serialization. Three of them stacked silently consume ~1.5GB.

Pass this to specialists doing diagnostic typecheck loops:

```
- Use at most ONE `npx tsc --noEmit <file>` per diagnostic step.
- After it completes: pkill -f "tsc --build" 2>/dev/null; sleep 1
- Verify no orphans: ps aux | grep "tsc --build" | grep -v grep | wc -l   # expect 0
- Once the bug is found, stop running --noEmit — let the specialist's commit-time validation handle compile verification.
```

**Python projects**: `mypy` and `pyright` do NOT spawn persistent worker processes the same way, so the orphan class doesn't apply. The analogous concern is the type-cache (`.mypy_cache/`, `pyright`'s in-memory cache) growing unbounded across many diagnostic invocations; instruct specialists to run typechecks with `--no-incremental` for one-shots if cache size becomes an issue, or `mypy --cache-dir=/dev/null`.

**Go / Rust / other compiled languages**: usually no orphan class — the compiler runs to completion and exits. Standard advice: don't fan out parallel compile invocations from the coordinator; let specialists handle compile verification in their own worktree.

---

## Multi-feature workflow

1. **One feature per specialist launch.**
2. **Wait for completion before launching the next specialist.** (Exception: explicit parallel waves with worktree isolation per "Parallel agents" above.)
3. **Update `progress.json` after each feature.**
4. **Never launch multiple specialists in serial mode in the same message** — context conflicts, resource exhaustion, and merge complexity all bite at once.

---

## Escalation handling

**Technical blocker** (missing dep, unclear req):
- Ask user for clarification
- Update progress.json with blocker note (`status: "blocked"`, blocker description in metadata)
- Defer feature to next session

**Quality gate failure** (tests failing, type errors):
- Dispatch debugger / test-automator
- Do NOT fix yourself
- Update progress.json with failure status

**Architectural decision needed**:
- Escalate to user
- Document decision in README
- Update progress.json with decision note

**Scope discovery** (specialist found something that changes the plan):
- Document the issue (`<PROJECT_DIR>/issues/ISSUE-XXX.md`)
- Dispatch focused review (backend-architect for design changes, security-auditor for security, database-admin for schema)
- Synthesize updates into the plan: revised `progress.json` features, README phase update, session-log entry
- Decision matrix:
  - Minor (< 4h, no new phases) → resume with updated plan
  - Moderate (4–8h, 1–2 new features) → update plan, resume same session
  - Major (> 8h, new phases) → end session, user approval required for revised plan

---

## Autonomous orchestration directive

Orchestrate using `haiku` agents for most everyday, well-defined work. Upgrade to `sonnet` or `opus` when the feature's spec or policy override demands it (see `harness-planner` for the matrix). Continue dispatching the next feature automatically after each completes — do not pause between features to ask "should I continue?"

**Human escalation triggers — stop and ask the user:**
- Ambiguous business requirements with no clear "right answer"
- Breaking changes to public APIs or shared contracts
- Security vulnerabilities that require policy decisions
- Database schema changes that affect production data integrity
- Failures that persist after opus-level debugging attempts

Until one of these fires, keep going.

---

## Optional — sync to PM33 (or any work-tracking MCP)

If the user has PM33 MCP configured and the harness has a corresponding work item, keep the status synced as work progresses:

| When | Transition | Tool |
|---|---|---|
| Coordinator picks up a feature | `backlog`/`planned` → `in_progress` | `pm33_update_work_item` |
| PR opened for a phase/feature | `in_progress` → `in_review` | `pm33_update_work_item` |
| PR merged | `in_review` → `done` | `pm33_update_work_item` |
| Work blocked | `in_progress` → `blocked` | `pm33_update_work_item` (include reason) |
| Unblocked | `blocked` → `in_progress` | `pm33_update_work_item` |

See the `pm33-mcp` skill for the full PM33 integration handbook, and `pm33-mcp-queue` for disconnect resilience (PM33 MCP can drop mid-session; queue failed writes and drain on reconnect).

**Sync is best-effort, not a gate.** A failed `pm33_update_work_item` does NOT block the work itself — log and continue.

**The reporting rule (NON-NEGOTIABLE)**: if PM33 (or any configured work-tracking MCP) was reached for and unavailable, the coordinator MUST surface the gap in the session report:

> ⚠️ PM33 MCP unreachable this session. Status not synced for N transitions. Queue file: `.claude/pm33-mcp-queue-<session-id>.jsonl`. Re-run with PM33 connected to drain.

If no work-tracking MCP is configured, no mention needed.

---

## Harness completion — PR to main

Ship when all features are `completed`, `init.sh` and `pre-commit-validation.sh` pass on the harness branch.

### 1. Push + open PR

```bash
git push -u origin "harness/${HARNESS_ID}"
PR_URL=$(gh pr create --base main --head "harness/${HARNESS_ID}" \
  --title "harness(${HARNESS_ID}): <summary>" \
  --body-file "$PROJECT_DIR/README.md" | tail -1)
PR_NUM=$(gh pr view "$PR_URL" --json number -q .number)
```

### 2. Dispatch the PR reviewer (independent judgment)

```
Task({
  subagent_type: "code-reviewer",
  description: "Review PR for harness/${HARNESS_ID}",
  prompt: `Independently review PR ${PR_NUM} (${PR_URL}).
    Inspect:  gh pr view ${PR_NUM}, gh pr diff ${PR_NUM}
    Context:  ${PROJECT_DIR}/README.md (the harness intent)
    Focus on: correctness, hidden side-effects, breaking changes, security,
              schema/auth implications, test coverage gaps, alignment with README.
    Post:     gh pr review ${PR_NUM} --approve
         OR:  gh pr review ${PR_NUM} --request-changes -b "<findings>"`
})
```

### 3. Merge if approved, otherwise fix-and-retry (max 3 iterations)

```bash
DECISION=$(gh pr view "$PR_NUM" --json reviewDecision -q .reviewDecision)
ITER=0
while [ "$DECISION" != "APPROVED" ] && [ $ITER -lt 3 ]; do
  ITER=$((ITER + 1))
  echo "Iteration $ITER — dispatching specialist to triage feedback"
  # Dispatch backend-architect / frontend-developer / database-admin / security-auditor
  # depending on what the review flagged. Specialist either applies fixes
  # (commit + push) or posts a pushback comment.
  DECISION=$(gh pr view "$PR_NUM" --json reviewDecision -q .reviewDecision)
done

if [ "$DECISION" = "APPROVED" ]; then
  gh pr merge --squash --delete-branch "$PR_NUM"
  cd "$(git rev-parse --git-common-dir | sed 's,/\.git$,,')"
  git worktree remove ".claude/worktrees/harness-${HARNESS_ID}"
  git branch -D "harness/${HARNESS_ID}" 2>/dev/null || true
  echo "✅ harness/${HARNESS_ID} merged + cleaned up."
else
  echo "⏸ After $ITER iterations the PR is not approved. Human review needed."
  gh pr view "$PR_NUM" --comments
fi
```

After 3 unsuccessful iterations the loop exits and the human sees all the back-and-forth on the PR.

**Multi-phase harnesses**: each shippable phase gets its own PR cycle. The harness branch only gets deleted after the FINAL phase merges — the `git worktree remove` / `git branch -D` block runs once at end-of-harness, not per-phase.

---

## End-of-session reporting template

```
## Harness Session Report — <HARNESS_ID>

Session: <date/time>
Features completed this session: <X of Y total>
Current phase: Phase <N>

### Completed
- ✅ FEAT-A.B: <description>
  - Specialist: <type> on <tier>
  - TDD: RED ✅ GREEN ✅ REFACTOR ✅ DELIVERY ✅
  - Commit: <sha>
  - Tests: <N>/<N> passing

### Next session
- 🔜 FEAT-A.C: <description> (<specialist>, <tier>, est <hours>)

### Context gaps (if any)
- ⚠️ <PM33 / other MCP unavailable; what couldn't be pulled or synced>

Estimated remaining: <hours> (<sessions>)
```

---

## Success criteria — per session

- [ ] At least 1 feature moved from pending → completed
- [ ] All quality gates passed for completed features (per pre-commit-validation.sh)
- [ ] progress.json updated with commit SHAs and timestamps
- [ ] session-log.txt appended with session summary
- [ ] Specialist followed TDD cycle (per `harness-discipline`)
- [ ] Clean git commit for each feature (in the harness worktree, not main)
- [ ] If PM33 / work-tracking MCP was unreachable, gap explicitly reported

---

## Anti-patterns

- ❌ Coordinator implementing code "to save time" — every line you write is a discipline failure
- ❌ Skipping `harness-discipline` skill load in the specialist prompt
- ❌ Running multiple specialists in parallel without per-agent worktrees
- ❌ Using raw `git merge` instead of `coordinator-merge.sh` (silent-drop class)
- ❌ Forcing a worktree cleanup that reports unmerged commits (`--force` without investigating)
- ❌ Treating work-tracking MCP sync as a blocking gate — it's best-effort
- ❌ Silent fallthrough when MCP context was unreachable — always report the gap
- ❌ Diagnosing "absorption" from a naive `git diff base..HEAD` without running the 30-second diagnostic above

---

## Related skills

- **harness-planner** — produces the plan you execute. Re-run only if the plan needs substantive revision.
- **harness-discipline** — what specialists load. Your job is to dispatch them with explicit instruction to load it.
- **harness-prep** — Phase 0 ahead of planning. You don't run it; the planner does.
- **gauntlet-review** — Phase 4 plan review. Should have happened before you got here.
- **pm33-mcp** — optional PM33 context-integration layer for status sync / context pull.
- **pm33-mcp-queue** — disconnect resilience for PM33 writes. Compose if PM33 MCP is in play.
- **superpowers:dispatching-parallel-agents** — general parallel-agent dispatch patterns (this skill applies the worktree-isolation specialization).
