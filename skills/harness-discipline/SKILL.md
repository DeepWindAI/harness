---
name: harness-discipline
description: TDD discipline and progress tracking for multi-session harness projects. Apply this skill when working on any long-running harness project (16+ hours, 3+ sessions) to ensure consistent TDD cycle, progress tracking, and reporting standards. Generic patterns work across all project types; if using PM33's internal harness conventions, see pm33-specific.md companion.
whenToUse: When working on harness projects of any kind, or when a harness coordinator assigns you work. Apply regardless of your specialist role (backend, frontend, database, etc.). For PM33-internal work, also consult pm33-specific.md.
triggers: ["harness project", "working on harness", "implement harness feature", "coordinator assigned me"]
relatedDocs: ["pm33-specific.md (if working in PM33)"]
---

# Harness Discipline Skill

**Purpose**: Apply consistent TDD cycle, progress tracking, and reporting standards when working on multi-session harness projects.

---

## 🔑 HOW TO USE THIS SKILL

**PM33-internal note**: If you're working inside PM33's internal repositories (pm-33-core, pm-33-monorepo, etc.) and need PM33-specific conventions (UTT master index, TECHNICAL_DEBT.md, OrbStack patterns, npm run test:locked, BUG-001 Drizzle examples), see the companion file `pm33-specific.md` in this skill's directory.

**If you are a SPECIALIST IMPLEMENTER** (backend-architect, frontend-developer, database-admin, etc.):

**Step 1 - Load this skill**:
```
Skill({ skill: "harness-discipline" })
```

**🚨 IMPORTANT**: Use skill name exactly as shown:
- ✅ CORRECT: `Skill({ skill: "harness-discipline" })`
- ❌ WRONG: `Skill(compounding-engineering:harness-discipline)` (no plugin prefix)
- ❌ WRONG: `Skill({ skill: "compounding-engineering:harness-discipline" })` (no plugin prefix)
- ❌ WRONG: Any namespace or prefix

**Step 2 - Follow the workflow in this skill**:
- Read context (startup section below)
- Apply TDD cycle (RED → GREEN → REFACTOR → DELIVERY)
- Update progress tracking (progress.json + claude-progress.txt)
- Report back to coordinator with evidence

**Use this skill when**:
- ✅ Working on a multi-session harness project (16+ hours, 3+ sessions)
- ✅ Assigned work by a harness-coordinator via Task tool
- ✅ Implementing features with TDD cycle and progress tracking
- ✅ Across any project type (backend, frontend, full-stack, etc.)

**🚨 IF YOU ARE THE COORDINATOR**:
- ❌ DO NOT use this skill yourself
- ❌ This skill is for IMPLEMENTERS, not COORDINATORS
- ✅ Your role: Launch specialists via Task tool with this skill reference
- ✅ See `agents/harness-coordinator.md` for your workflow

---

## 🎯 CORE PRINCIPLE

**You maintain your specialist identity** (backend-architect, frontend-developer, etc.) while applying harness discipline to your work.

**Harness discipline = TDD cycle + Progress tracking + Evidence-based reporting**

**You are the IMPLEMENTER**: You write code, run tests, commit changes. The coordinator orchestrates; you execute.

---

## 🛑 PHASE 0 — Environment verification (MANDATORY, FIRST ACTION)

**Before reading any file, running any test, or touching git, you MUST verify
your environment matches what the coordinator dispatched you with.** This is
the first action of the session — earlier than reading context, earlier than
loading specs. If any check below mismatches, STOP and report back to the
coordinator. Do not attempt to "fix it" by running `git checkout` yourself —
a mismatch means the dispatch broke and the coordinator needs to know.

Why this exists (2026-06-19): a FEAT-0.2 specialist committed straight to
`main` because their working tree was the main repo, not the harness worktree
the coordinator described in the preamble. The specialist didn't notice the
mismatch and the branch-pin hook is only one layer — this verification step
is the line of defense that catches it BEFORE the first edit.

The coordinator's Task prompt always includes a preamble with three values:

```
**Working directory**: <path to harness worktree, or per-agent worktree>
**Branch**: harness/<HARNESS_ID>   (or worktree-agent-<AGENT_ID>)
**Agent ID**: <HARNESS_ID>-<feature-id>-<specialist>
```

Run these checks against those values **in this order**:

```bash
# 1. Confirm working directory matches the preamble's "Working directory:"
echo "EXPECTED cwd: <paste from preamble>"
echo "ACTUAL   cwd: $(pwd)"

# 2. Confirm branch matches the preamble's "Branch:"
echo "EXPECTED branch: <paste from preamble>"
echo "ACTUAL   branch: $(git branch --show-current)"

# 3. Confirm agent ID is set in env
echo "EXPECTED agent ID: <paste from preamble>"
echo "ACTUAL   agent ID: ${CLAUDE_AGENT_ID:-(unset)}"

# 4. Confirm you are inside a worktree, not the main repo
git rev-parse --show-toplevel
git rev-parse --absolute-git-dir
# If absolute-git-dir is just <repo>/.git, you are in the main worktree.
# If absolute-git-dir is <repo>/.git/worktrees/<name>, you are in a worktree.

# 5. Confirm the branch is NOT a protected branch (defense in depth)
case "$(git branch --show-current)" in
  main|master|staging|production|release-*)
    echo "🚨 FATAL: dispatched onto protected branch. Report to coordinator." >&2
    exit 1
    ;;
esac
```

**If ANY of (1), (2), (3), (5) mismatches**:

1. STOP. Do not run any other command.
2. Do not `git checkout`, `git switch`, `cd`, or modify env yourself.
3. Report back to the coordinator with both expected and actual values, e.g.:

```
🛑 Environment mismatch — refusing to start work.

Coordinator preamble said:
  Working directory: /Users/.../.claude/worktrees/harness-foo
  Branch: harness/foo
  Agent ID: foo-feat-0-2-backend

Actual:
  pwd: /Users/.../pm-33-core
  branch: main
  CLAUDE_AGENT_ID: (unset)

This looks like the dispatch landed in the main worktree, not the harness
worktree. Please re-issue the Task with a `cd` into the worktree, or
provision the worktree via spawn-worktree.sh first.
```

4. WAIT for the coordinator to re-dispatch. Do not improvise.

Only after all five checks match do you proceed to STARTUP.

---

## 📋 STARTUP: Read Context (5 min)

**MANDATORY - Before starting any harness work**:

1. **Read feature requirements**:
```bash
# Check your project's feature tracking (progress file, Linear/Jira, etc.)
cat progress.json  # or whatever your project uses
# Find your assigned feature (status: "in_progress" or next pending)
```

2. **Read recent progress**:
```bash
# Check session logs or commit history
tail -100 progress-log.txt  # or whatever your project uses
git log --oneline --since="7 days ago" | head -20
# Understand what was completed, what's next
```

3. **Read harness documentation**:
```bash
# Check if your harness has a README or specs
cat README.md  # in your harness directory if present
# Understand quality standards, acceptance criteria
```

4. **Read coordinator's context** (if provided):
- Technical context (feature spec, code samples, schema)
- Documentation references (wireframes, architecture)
- Quality standards (test coverage, performance targets)
- Test scenarios
- Validation instructions (gates to pass, reporting format)

---

## 🧠 MEMORY MANAGEMENT (MANDATORY)

**🚨 CRITICAL**: Test execution has strict memory limits to prevent system exhaustion.

### Memory Limits

| Resource | Limit | Configuration |
|----------|-------|---------------|
| **Vitest/Jest workers** | 2 max | `maxForks: 2` in test config |
| **Per-worker memory** | 2GB | `--max-old-space-size=2048` |
| **Total test memory** | 4GB max | 2 workers × 2GB each |
| **TypeScript compilation** | 3GB | `NODE_OPTIONS=--max-old-space-size=3072` |

### Test Command — Detect-or-Fallback Pattern

Check your repo for an available test coordination mechanism:

```bash
# 1. Check if your repo has a test:locked script
if npm run | grep -q "test:locked"; then
  # ✅ Use coordinated test runner (if available in your project)
  npm run test:locked -- [feature].test.ts
else
  # ✅ Fall back to standard test runner (ensure serial execution)
  npm test -- [feature].test.ts --maxWorkers=2
fi
```

**Key principle**: Prevent multiple agents from running tests simultaneously to avoid memory exhaustion.

### Sequential Validation Pattern

**Run validation commands ONE AT A TIME**:

```bash
# ✅ CORRECT - Sequential with &&
npm run type-check && npm test && npm run lint

# ❌ WRONG - Parallel execution can cause memory issues
npm run type-check & npm run test & npm run lint
```

### Post-Test Cleanup

**After completing tests, verify no hung processes**:

```bash
# Check for lingering test processes
ps aux | grep -E "node|jest|vitest" | grep -v grep

# If you have a cleanup script available, use it
if npm run | grep -q "cleanup"; then
  npm run cleanup
fi
```

### Multi-Agent Coordination

**THE PROBLEM**: Multiple agents running tests simultaneously defeats memory limits.

**MANDATORY RULE**:
- **ONLY ONE AGENT may run tests at a time**
- If tests are already running, **WAIT** or **SKIP**
- Check with: `ps aux | grep -E "jest|vitest"`

---

## 🔄 TDD CYCLE (MANDATORY - Every Feature)

### Phase 1: RED (Write Failing Test First)

**Before writing ANY implementation code**:

```bash
# 1. Create test file or add to existing
# 2. Write test for new feature
# 3. Run test - EXPECT IT TO FAIL

npm test -- [feature].test.ts

# ✅ Success criteria: Test fails (red)
# ❌ If test passes: You're testing existing functionality, not new feature
```

**Why RED matters**: Proves test actually validates the feature (prevents false confidence)

### Phase 2: GREEN (Make Test Pass)

**Before writing GREEN tests for any middleware/service that touches the DB**:
- [ ] Does this code execute SQL (raw SQL or via ORM)? If yes → use real test DB, NOT mocked queries
- [ ] If you mock at the DB layer, your test verifies your mock, not your code
- [ ] If real-DB tests are infeasible for this harness, document the gap in your project's debt tracker — DO NOT silently substitute mocks

**See "Mock vs Real DB" section below for patterns and decision tree.**

**Write minimal code to pass the test**:

```bash
# 1. Implement feature (simplest possible code)
# 2. Run test - EXPECT IT TO PASS

# Choose the command for your test runner:
#   JS/TS:   npm test -- [feature].test.ts
#   Python:  pytest tests/test_feature.py -k <test_name>
#   Go:      go test -run TestName ./pkg/...
#   Ruby:    bundle exec rspec spec/feature_spec.rb -e "test name"

# ✅ Success criteria: Test passes (green)
# ❌ If test fails: Debug implementation, don't skip to refactor
```

**Why GREEN matters**: Proves implementation works (establishes working baseline)

### Phase 3: REFACTOR (Clean Up)

**Improve code quality while keeping tests green**:

```bash
# 1. Remove duplication, improve naming, simplify logic
# 2. Run test - EXPECT IT TO STILL PASS

npm test -- [feature].test.ts

# ✅ Success criteria: Tests still pass after refactoring
# ❌ If tests fail: Refactoring broke functionality, revert and retry
```

**Why REFACTOR matters**: Maintains code quality without sacrificing working functionality

### Phase 4: DELIVERY (Full Validation)

**Run all quality gates before commit**:

```bash
# If your harness project has a validation script, run it
if [ -f "pre-commit-validation.sh" ]; then
  ./pre-commit-validation.sh
elif [ -f ".github/workflows/test.yml" ]; then
  npm run build && npm test  # Fallback to standard validation
else
  npm run type-check && npm test && npm run lint  # Generic validation
fi

# Expected gates typically include:
# 1. TypeScript compilation: ✅
# 2. Linting (ESLint): ✅
# 3. Unit tests: ✅
# 4. Integration tests: ✅
# 5. Type safety validation: ✅
# 6. Documentation consistency: ✅
# [Add project-specific gates as needed]
```

**If any gate fails**:
- Fix issue before proceeding
- Do NOT skip gates
- Do NOT commit until all gates pass

**When all gates pass**:
```bash
# Ensure you are inside your own worktree (NOT the shared main repo).
# `git add .` on the shared main worktree absorbs files written by other
# concurrent specialists into your commit — a documented absorption class.
#
# If you have not yet entered a worktree (see "Worktree isolation" in the
# coordinator's launch prompt), do it now using the bundled scripts at
# `~/.claude/skills/harness-coordinator/scripts/`:
if [ "$(git rev-parse --absolute-git-dir)" = "$(git rev-parse --path-format=absolute --git-common-dir)" ]; then
  AGENT_ID="${CLAUDE_AGENT_ID:-feature-$(date +%s)}"
  WORKTREE=$(bash ~/.claude/skills/harness-coordinator/scripts/spawn-worktree.sh "$AGENT_ID")
  cd "$WORKTREE"
  export CLAUDE_AGENT_ID="$AGENT_ID"
fi

# Now `git add .` is safe — the worktree only sees your own files.
# Commit ONE feature only.
git add .
git commit -m "FEAT-XXX: [description] - All validation gates PASSED"
```

---

## 🗄️ MOCK VS REAL DB — CRITICAL DISTINCTION

### The Core Principle

**Golden rule**: Mocks at the database layer hide schema mismatches. If your code executes SQL (raw or via ORM), test against a REAL database that mirrors your actual schema.

**Why**: Three layers of mocked testing can all pass while your code fails in production because the mocks synthesize schema fields that don't actually exist. Mocks verify the mock, not the code.

### Decision Tree

**Use REAL TEST DB if**:
1. Code executes SQL (raw: `db.execute(sql\`...\`)`or ORM: `db.select().from(...)`)
2. Code calls a function that executes SQL
3. Schema validation matters (table structure, column types, constraints)

**Use MOCKS if**:
1. Code transforms data from elsewhere (data → format conversion)
2. Code renders UI from props/API responses (component isolation test)
3. Code has zero DB dependencies

**When in doubt: REAL DB is safer.**

### Categories with Examples

**🔴 ALWAYS REAL DB**:
- Express middleware that runs SQL: `(req, res, next) => { const rows = await db.select()... }`
- Service-layer functions with dynamic queries: `getWorkspaceRisk(workspaceId) => db.select().from(workItems).where(...)`
- Auth/access-control logic that joins tables: permission checks against database state
- Migrations and schema validation

**🟡 VALIDATE FIRST, THEN DECIDE**:
- Hooks that call API endpoints: Mock the API response (not the DB), test component isolation
- Utility functions that accept data: Mock the input data, test transformation logic
- Middleware that depends on a service: Real test DB if service queries; mock if service is pure logic

**🟢 ALWAYS MOCKS**:
- Component rendering tests: Mock props, test JSX output
- Data transformers: Mock input, test output format
- Validators and formatters: Mock data, test logic
- UI state management: Mock API calls, test state transitions

### Anti-Patterns (What NOT to Do)

```typescript
// ❌ WRONG: Mocks a query at the db layer
vi.mock('../db', () => ({
  execute: vi.fn().mockResolvedValue({ rows: [
    { id: '123', deleted_at: null }  // synthesized schema
  ]}),
}));

// ❌ WRONG: Mocks individual middleware SQL
db.execute = vi.fn().mockResolvedValue({ 
  rows: [{ workspace_id: '...', deleted_at: null }]  // imagined fields
});

// ❌ WRONG: Mocks Drizzle query builder for routes/services
vi.mock('drizzle-orm', () => ({
  eq: vi.fn(),
  and: vi.fn(),
  select: vi.fn().mockReturnValue({
    from: vi.fn().mockReturnValue({
      where: vi.fn().mockResolvedValue([{ ... }])
    })
  })
}));
```

### Correct Patterns for Fast Real-DB Tests

**Pattern 1: Transaction Rollback (Fastest)**
```typescript
// Wrap each test in a transaction, rollback after
beforeEach(() => {
  client.query('BEGIN');
});

afterEach(() => {
  client.query('ROLLBACK');
});

test('middlewareValidatesWorkspace', async () => {
  // Insert real test data
  await db.insert(workspaces).values({ id: 'test-1', ... });
  
  // Run middleware, verify database behavior
  const result = await middleware(req, res, next);
  expect(result).toBe(expectedOutcome);
});
```

**Pattern 2: Deterministic Test Database with Seeding**
```typescript
// Seed test data once per suite
beforeAll(() => {
  seedTestDatabase({
    workspaces: [{ id: 'test-workspace', ... }],
    users: [{ id: 'test-user', workspaceId: 'test-workspace' }]
  });
});

afterEach(() => {
  // Clean up per test
  db.delete(workItems).where(eq(workItems.workspaceId, 'test-workspace'));
});

test('middlewareChecksAccess', async () => {
  const { req, res } = createTestRequest({ workspaceId: 'test-workspace' });
  await middleware(req, res, next);
  expect(res.status).toBe(200);
});
```

**Pattern 3: Use Your Repository's Test Database**
- Set up a test database that mirrors your schema (Docker, local Postgres, managed service)
- Run tests against that database consistently
- No setup/teardown overhead between test runs
- Schema always matches reality
- Configure in your repo's test setup (e.g., `vitest.config.ts`, `jest.config.js`, or test harness init script)

### When Real-DB Tests Are Infeasible

If real-DB tests cannot work for this harness (e.g., no test container available, integration test limitations), document the gap:

```markdown
### DB-TEST-001: Mocked queries in [service name]

**Issue**: [Middleware/service name] runs SQL but we mock queries for speed

**Reason**: [Test container not available / integration tests fail with real DB / other constraint]

**Mitigation**: [Use [Pattern] OR document manual validation OR create follow-up task]

**Risk**: Mocks may diverge from schema. Validate schema manually before deployment.

**Follow-up**: [Link to task to enable real-DB tests or schema validation]
```

### Reference

- **Complete convention doc**: `docs/conventions/TESTING_REAL_DB_VS_MOCKS.md` (if available in your project)
- **Test patterns**: Look at your project's existing test suite (e.g., `__tests__/`, `tests/`) for transaction rollback and seeding examples

---

## 📊 PROGRESS TRACKING (After Each Feature)

### Update feature progress tracking

**After completing DELIVERY phase**, update your project's feature tracking file:

```json
{
  "id": "FEAT-XXX",
  "status": "completed",  // Change from "in_progress" to "completed"
  "tddPhases": {
    "RED": "completed",
    "GREEN": "completed",
    "REFACTOR": "completed",
    "DELIVERY": "completed"
  },
  "validationResults": {
    "testCoverage": "97%",
    "gitCommit": "abc1234",
    "completedAt": "2025-12-09T15:30:00Z"
  }
}
```

### Update claude-progress.txt

**Append session entry** (do this ONCE per feature completion):

```markdown
## Session [N] - YYYY-MM-DD

**Feature Completed**: FEAT-XXX - [Feature name]

**TDD Phases**:
- RED: ✅ Test written, initially failed
- GREEN: ✅ Implementation complete, test passed
- REFACTOR: ✅ Code cleaned up, tests still pass
- DELIVERY: ✅ All validation gates passed

**Validation Results**:
- Test Coverage: 97% (target: ≥95%)
- TypeScript: ✅ No errors
- ESLint: ✅ No warnings
- Performance: [metric if applicable]
- Git Commit: abc1234

**Files Modified**:
- server/routes/example.ts (lines 45-67)
- server/services/exampleService.ts (lines 12-34)
- tests/example.test.ts (lines 8-56)

**Next Feature**: FEAT-YYY - [Next feature name] (estimated 4 hours)
```

### Update Project Work Index (If Available)

**Document completed features** (do this ONCE per feature completion):

If your project tracks completed work in a central index (e.g., a master index file, Linear/Jira board, task tracker), append an entry there per your project's convention.

**Example entry format**:
```markdown
### [Harness Project Name] - FEAT-XXX: [Feature Name]

**Status**: ✅ Completed
**Completed**: YYYY-MM-DD
**Specialist**: [your-role]
**Git Commit**: abc1234

**Summary**: [1-2 sentence description]

**Validation Results**:
- Test Coverage: 97%
- TypeScript: ✅ No errors
- ESLint: ✅ No warnings
- All quality gates: ✅ PASSED

**Files Modified**:
- [file1:lines]
- [file2:lines]
```

**Why This Matters**: Documenting completed work enables team members to find implementations without searching git history and provides audit trail for the harness project.

### Document Technical Debt (When Necessary)

**When to document technical debt**:
- 🔴 **P0 (Critical)**: Security vulnerabilities, data loss risks, production blockers
- 🟡 **P1 (High)**: Performance issues, maintainability concerns, breaking API changes needed
- 🟢 **P2 (Medium)**: Code quality improvements, missing tests, documentation gaps

**Document in your project's debt tracker**:
- If you have a designated `TECHNICAL_DEBT.md` file, add an entry there
- If you use a Linear/Jira board, create an issue tagged with "technical-debt"
- If you have a PM33 work item or other convention, use that
- If none exist, file an inline comment in the relevant code file with a clear debt marker

**Example entry format**:

```markdown
### [PRIORITY]-XXX: [Brief description]

**Priority**: P0/P1/P2
**Discovered**: YYYY-MM-DD
**Discovered During**: [Feature name]
**Specialist**: [your-role]

**Impact**: [What breaks or degrades if not fixed]

**Root Cause**: [Why this issue exists]

**Recommended Fix**: [Specific steps to resolve]

**Requires**: [Architect approval / DBA review / Security audit / etc.]
```

**Why This Matters**: Proper technical debt documentation prevents issues from being forgotten, enables prioritization across your team, and creates audit trail for architectural decisions.

---

## 💬 REPORTING BACK (To Coordinator or User)

**Status Report Template**:

```markdown
## Feature FEAT-XXX: [name] - ✅ COMPLETE

**Specialist**: [your-role: backend-architect, frontend-developer, etc.]

**TDD Cycle**:
- RED: ✅ Test written, initially failed as expected
- GREEN: ✅ Feature implemented, test passed
- REFACTOR: ✅ Code cleaned up, tests still green
- DELIVERY: ✅ All 10 quality gates passed

**Validation Evidence**:
- Test Coverage: 97% (target: ≥95%)
- TypeScript: ✅ 0 errors
- ESLint: ✅ 0 warnings
- Performance: [metric] (target: [target])
- Security: ✅ Input validation, tenant isolation verified
- Git Commit: abc1234

**Files Modified**:
- [file1:lines]
- [file2:lines]
- [file3:lines]

**Issues Discovered**: [None / See escalation below]

**Progress Update**:
- Feature tracking updated: FEAT-XXX marked completed
- Session notes appended: Session entry added
- Work index updated: Feature documented (if applicable)
- Debt tracker updated: [None / Issues documented as needed]
- Git commit successful: abc1234

**Ready for**: Next feature (FEAT-YYY) or coordinator review
```

---

## 🚨 ESCALATION PROTOCOL

**When you need guidance or discover issues during implementation**:

### 🔵 CONSULT EXPERT SPECIALISTS (WHEN UNCERTAIN)

**🚨 CRITICAL**: If you are unsure about the path forward, you MUST consult architect and/or DBA BEFORE continuing implementation.

**Consult backend-architect if uncertain about**:
- API design decisions (endpoints, request/response structure)
- Service boundaries (which service should own this logic)
- Architecture patterns (how to structure the code)
- Integration approaches (how to connect systems)
- Security implementation (authentication, authorization patterns)

**Consult database-admin if uncertain about**:
- Database schema changes (tables, columns, indexes)
- Migration strategies (how to safely alter schema)
- Query optimization (performance concerns)
- Data modeling decisions (normalization, relationships)
- Transaction boundaries (where to use transactions)

**Action**:
1. STOP implementation at current state
2. Use Task tool to launch architect and/or DBA for review:

```typescript
Task({
  subagent_type: 'backend-architect',  // or 'database-admin'
  description: 'Review [feature-name] architecture/design',
  prompt: `**REVIEW REQUEST FROM SPECIALIST**

I am implementing [feature-name] and need architectural guidance.

**Current Context**:
- Feature: [FEAT-XXX - description]
- Harness Project: [your project name]
- Implementation Progress: [what I've completed so far]

**Uncertainty**:
[Describe what you're uncertain about - specific questions]

**Options Considered**:
1. [Option A - pros/cons]
2. [Option B - pros/cons]
3. [Option C - pros/cons]

**Documentation Reviewed**:
- [List files you've read: specs, existing code, documentation]

**Your Task**:
1. Review the documentation and existing code
2. Review the feature requirements in progress.json
3. Provide clear recommendation on path forward
4. Explain rationale for recommendation

**Report Back**:
- Recommended approach (which option or alternative)
- Rationale (why this approach is best)
- Implementation guidance (key steps to follow)
- Potential risks to watch for`
});
```

3. WAIT for architect/DBA response with recommendations
4. RESUME implementation following their guidance
5. Document their recommendation in commit message:
   ```
   FEAT-XXX: [description]

   Architecture reviewed by backend-architect: [recommendation summary]
   [implementation details]
   ```

**Why This Is Critical**:
- Prevents architectural mistakes that are costly to fix later
- Ensures database changes follow best practices
- Maintains system consistency and quality standards
- Leverages expert knowledge for complex decisions

**🚨 IF YOU DON'T ASK WHEN UNCERTAIN**: Coordinator will detect this and require architect/DBA review anyway, which delays the feature. Always ask proactively when uncertain.

---

### 🔴 RED (STOP WORK IMMEDIATELY)

**Stop if**:
- Security vulnerability discovered
- Data loss risk identified
- Production blocker found
- Breaking API change required

**Action**:
1. STOP all work immediately
2. Document in your project's debt tracker (TECHNICAL_DEBT.md, Linear, Jira, etc.):
   ```markdown
   ### RED-XXX: [Brief description]
   **Priority**: P0 | **Discovered**: YYYY-MM-DD
   **Impact**: [What breaks if not fixed]
   **Requires**: Architect approval before proceeding
   ```
3. Report to coordinator/user: "🔴 RED issue discovered - work stopped, architect approval needed"
4. WAIT for approval before continuing

### 🟡 YELLOW (REPORT BUT CONTINUE)

**Report if**:
- Performance degradation noticed
- Maintainability concerns found
- Technical debt discovered
- Missing documentation identified

**Action**:
1. Document in your project's debt tracker (TECHNICAL_DEBT.md, Linear, Jira, etc.):
   ```markdown
   ### YELLOW-XXX: [Brief description]
   **Priority**: P1/P2 | **Discovered**: YYYY-MM-DD
   **Impact**: [Degradation but not blocking]
   **Recommendation**: [Suggested fix]
   ```
2. Mention in status report
3. Continue with current feature

### 🟢 GREEN (FIX INLINE)

**Fix immediately if**:
- Minor code quality issues
- Missing comments
- Unused imports
- Style inconsistencies

**Action**:
1. Fix inline during REFACTOR phase
2. Mention in commit message
3. No separate documentation needed

---

## ✅ COMPLETION CHECKLIST

**Before reporting feature complete, verify**:

### Context
- [ ] Read progress.json and identified your feature
- [ ] Read last 3 sessions from claude-progress.txt
- [ ] Checked git log for recent work
- [ ] Read harness README for quality standards
- [ ] Read coordinator's context package (if provided)

### TDD Cycle
- [ ] RED: Test written, initially failed (ran test suite)
- [ ] GREEN: Feature implemented, test passed (ran test suite)
- [ ] REFACTOR: Code cleaned up, tests still pass (ran test suite)
- [ ] DELIVERY: All quality gates passed
- [ ] POST-TEST: Verified no hung processes

### Quality
- [ ] Test coverage ≥95%
- [ ] Performance targets met
- [ ] Security requirements validated (input validation, tenant isolation)
- [ ] Acceptance criteria verified
- [ ] JSDoc comments added

### Progress Tracking
- [ ] Feature progress tracked (per your project's tracking method)
- [ ] Session notes documented (what was completed, what's next)
- [ ] Work index updated (if your project has one)
- [ ] Technical debt documented (if issues discovered)
- [ ] Git commit successful (one feature per commit)

### Reporting
- [ ] Status report prepared with evidence
- [ ] Issues escalated (if any) per protocol
- [ ] Coordinator/user notified of completion

---

## 🎓 KEY PRINCIPLES TO REMEMBER

### 1. One Feature Per Session
**Focus on single feature**, complete full TDD cycle, commit, then move to next.
- ✅ DO: FEAT-001 complete → commit → FEAT-002 start
- ❌ DON'T: Start FEAT-001 + FEAT-002 simultaneously

### 2. TDD Is Not Optional
**All 4 phases required** (RED → GREEN → REFACTOR → DELIVERY)
- ✅ DO: Write test first, see it fail, implement, refactor, validate
- ❌ DON'T: Skip RED phase, skip tests, defer validation

### 3. Evidence Over Claims
**Prove completion** with validation results, not just "I think it works"
- ✅ DO: "Test coverage: 97%, git commit: abc1234"
- ❌ DON'T: "Looks good, probably works"

### 4. Quality Gates Are Mandatory
**All gates must pass** before commit
- ✅ DO: Fix failures, rerun gates until all pass
- ❌ DON'T: Skip gates, commit with failures, defer fixes

### 5. Progress Tracking Is Critical
**Update progress files** after every feature
- ✅ DO: Update progress.json + claude-progress.txt immediately
- ❌ DON'T: Batch updates, forget to track, skip documentation

---

## 📚 REFERENCE

**For PM33-internal harness work**: See companion file `pm33-specific.md` in this skill's directory (has PM33-specific protocols, OrbStack patterns, BUG-001 lesson with code examples)

---

## 💡 EXAMPLE SESSION

**Scenario**: You're backend-architect working on FEAT-003 in a harness project

**Startup** (5 min):
```bash
# 1. Read context
cat progress.json  # your project's tracking file
# → Found FEAT-003: "Implement error categorization service"

tail -100 progress-log.txt
# → Previous session completed FEAT-002, next is FEAT-003

# 2. Understand requirements
# → FEAT-003 acceptance criteria: categorize errors by severity, store metadata
```

**TDD Cycle** (45 min) — example uses JS/TS commands; substitute your runner (pytest, go test, rspec, etc.) for your stack:
```bash
# RED: Write test
# Created: server/services/__tests__/errorCategorizationService.test.ts
# (Python equivalent: tests/services/test_error_categorization.py)
# Test expects categorizeError() to return {severity, category, metadata}
npm test -- errorCategorizationService.test.ts        # JS/TS
# pytest tests/services/test_error_categorization.py  # Python
# ✅ Test fails (function doesn't exist yet)

# GREEN: Implement
# Created: server/services/errorCategorizationService.ts
# (Python: server/services/error_categorization.py)
# Implemented categorizeError() with basic logic
npm test -- errorCategorizationService.test.ts        # JS/TS
# pytest tests/services/test_error_categorization.py  # Python
# ✅ Test passes

# REFACTOR: Clean up
# Extracted severity detection to separate function
# Improved naming, added docstrings/JSDoc comments
npm test -- errorCategorizationService.test.ts        # JS/TS
# pytest tests/services/test_error_categorization.py  # Python
# ✅ Tests still pass

# DELIVERY: Validate
npm run type-check && npm test && npm run lint
# ✅ All validation gates passed

# POST-TEST: Cleanup
ps aux | grep -E "jest|vitest" | grep -v grep  # verify no hung tests
```

**Progress Tracking** (5 min):
```bash
# Update progress.json: FEAT-003 status → "completed"
# Append progress-log.txt: Session entry with validation results
# Commit: git commit -m "FEAT-003: Implement error categorization - All gates PASSED"
```

**Reporting** (2 min):
```markdown
## Feature FEAT-003: Implement error categorization - ✅ COMPLETE

**Specialist**: backend-architect

**TDD Cycle**: All 4 phases completed
**Validation**: 98% coverage, 0 errors, git: def5678
**Files**: errorCategorizationService.ts, tests
**Next**: FEAT-004 (estimated 3 hours)
```

---

**Remember**: You are a specialist applying harness discipline, not a harness-specialist wrapping your work. Your expertise (backend, frontend, database) remains primary; this skill adds structure and accountability.
