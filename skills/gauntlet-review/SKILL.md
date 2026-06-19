# Gauntlet Review Skill

**Purpose**: Coordinate antagonistic specification reviews by multiple specialists to catch architectural issues, security gaps, scalability risks, and testability problems BEFORE implementation begins.

**Status**: PRODUCTION READY
**Last Updated**: 2026-02-14

---

## Skill Overview

The Gauntlet Review Skill orchestrates parallel specialist reviews of project specifications from different perspectives. Each specialist acts as a "friendly adversary," challenging assumptions and finding problems that might be missed by primary implementers.

**Core Principle**: Different expertise discovers different problems
- Backend architects find database issues
- Database admins find query inefficiency
- Security auditors find authorization gaps
- Code reviewers find design patterns and testability issues
- Performance engineers find scalability risks
- AI engineers find integration and safety issues

---

## How to Use This Skill

### For Gauntlet Coordinators

```bash
# Load the skill
Skill({ skill: "gauntlet-review" })

# Then coordinate reviews like this:
Task({
  subagent_type: "harness-coordinator",
  description: "Run specification review gauntlet",
  prompt: `Load Skill({ skill: "gauntlet-review" })

Your task: Coordinate 6 parallel specification reviews for Employee Management System.

Reviews to conduct:
1. feature-dev:backend-architect → Reviews DATABASE_ARCHITECTURE_PLAN.md
2. database-admin → Reviews BACKEND_ARCHITECTURE_DESIGN.md (services)
3. security-auditor → Reviews backend + database (security, isolation)
4. feature-dev:code-reviewer → Reviews all specs (testability, design patterns)
5. performance-engineer → Reviews all specs (scalability, performance)
6. ai-engineer → Reviews AI specs + integration

Reference documents:
- DATABASE_ARCHITECTURE_PLAN.md (103 KB)
- BACKEND_ARCHITECTURE_DESIGN.md (57 KB)
- ai-implementation-plan.md (103 KB)
- AGENT_TASK_ASSIGNMENT.md (30 KB)
- FRONTEND_SPECIFICATION.md (80 KB)

Use the gauntlet-review skill format for each review:
- Each reviewer produces: Critical Issues | Concerns | Risks | Gaps | Summary
- Coordinate all 6 in parallel
- Synthesize findings
- Provide go/no-go recommendation for Phase 1 launch
`
})
```

### For Individual Reviewers

Each specialist receives a review task like:

```bash
Task({
  subagent_type: "feature-dev:backend-architect",
  description: "Antagonistic review: Database schema efficiency",
  prompt: `You are reviewing the Employee Management System specifications for architectural issues.

GAUNTLET REVIEW FORMAT:

Review Type: Database Schema Efficiency Review
Reviewed By: feature-dev:backend-architect
Documents: DATABASE_ARCHITECTURE_PLAN.md
Perspective: "Can these services query the schema efficiently?"

Task: Find problems and attack weaknesses

CRITICAL ISSUES (STOP IMPLEMENTATION):
- List issues that block Phase 1
- Format: 🔴 CRITICAL: [Issue] | Severity: BLOCKER
- Include: Location, impact, recommendation

ARCHITECTURAL CONCERNS (HIGH PRIORITY):
- List concerns that need discussion
- Format: 🟡 CONCERN: [Issue] | Severity: HIGH
- Include: Description, recommendation

SCALABILITY RISKS (WATCH FOR):
- List risks at scale (100K+ employees)
- Format: ⚠️ RISK: [Issue] | Current Limit, Growth Path

TESTABILITY GAPS (IF APPLICABLE):
- List hard-to-test components
- Format: 🧪 GAP: [Issue] | Test Challenge, Mitigation

SUMMARY & RECOMMENDATION:
- APPROVAL: ✓ APPROVED | ⚠️ CONDITIONAL | ✗ BLOCKED
- Can Phase 1 proceed? Why or why not?

Reference: /docs/frameworks/agent-state-employee-management/REVIEW_GAUNTLET_PLAN.md
`
})
```

---

## Review Checklist

Each reviewer should cover:

### 1. Critical Issues 🔴

**Format**:
```
🔴 CRITICAL ISSUE: [Short title]
Severity: BLOCKER (stops implementation) | DEFECT (must fix)
Location: [Document file and section]
Description: [Specific problem with evidence]
Impact: [What breaks if not fixed?]
Recommendation: [Specific fix required]
```

**Examples**:
- BLOCKER: Missing tenant_id filter in query
- BLOCKER: Foreign key cascade will delete active data
- DEFECT: N+1 query pattern in availability calculation
- DEFECT: Race condition in approval workflow

### 2. Architectural Concerns 🟡

**Format**:
```
🟡 CONCERN: [Short title]
Severity: HIGH (needs resolution) | MEDIUM (nice to fix)
Description: [Potential problem and why it matters]
Evidence: [Why you think this is an issue]
Recommendation: [How to address it]
Alternative Approaches: [Other ways to solve this]
```

**Examples**:
- Materialized views may lag real-time needs
- Service interface exposes database schema directly
- Missing abstraction layer for classification system

### 3. Scalability Risks ⚠️

**Format**:
```
⚠️ RISK: [Short title]
Current Bottleneck: [What breaks at X scale?]
Symptom: [What you'd observe - slow queries, memory, etc.]
Growth Path: [How to handle 10x growth?]
Mitigation: [What to do now vs. Phase 6]
```

**Examples**:
- Team availability query is O(n²), breaks at 5K+ employees
- WebSocket connections need connection pooling at 1000+ managers
- Bulk import processes 1 employee/sec, breaks at 10K+ files

### 4. Testability Gaps 🧪

**Format**:
```
🧪 GAP: [Short title]
Test Challenge: [Why hard to test?]
Example Test Case: [Specific test that's problematic]
Mitigation: [How to make it testable]
Risk if Not Addressed: [What breaks in Phase 6 testing?]
```

**Examples**:
- Velocity cascade hard to test end-to-end (multiple services)
- WebSocket real-time updates not deterministic
- Deduplication algorithm has flaky edge cases

### 5. Summary & Recommendation

**Format**:
```
REVIEW RESULT: ✓ APPROVED | ⚠️ CONDITIONAL | ✗ BLOCKED

Assessment: [1-2 sentence summary of overall quality]

Recommendation: [Can Phase 1 proceed?]
- ✓ YES - No blockers found
- ⚠️ YES WITH FIXES - Minor issues found, document in TECHNICAL_DEBT.md
- ✗ NO - Critical blockers, must fix before Phase 1

Critical Path Items (must do before Phase 1):
- [ ] Item 1 (what, why, how to verify)
- [ ] Item 2 (what, why, how to verify)

Phase 2+ Items (schedule for later):
- [ ] Item A (what, why, priority)
- [ ] Item B (what, why, priority)
```

---

## Review Focus Areas by Specialist

### 1. feature-dev:backend-architect
**Reviews**: DATABASE_ARCHITECTURE_PLAN.md
**Perspective**: "Will our services query this efficiently?"
**Attack Angle**: Find missing indexes, over-indexing, schema design issues
**Key Questions**:
- Are all 57 indexes necessary? Over-indexed?
- Can services query what they need?
- Will 12 triggers cause performance problems?
- Is soft delete filtering applied everywhere?
- Will schema support 100K+ employees?

### 2. database-admin
**Reviews**: BACKEND_ARCHITECTURE_DESIGN.md (Parts 1-2)
**Perspective**: "Will these services write efficient queries?"
**Attack Angle**: Find N+1 patterns, materialization misses, query inefficiency
**Key Questions**:
- What queries will be most expensive?
- Do we need additional indexes?
- Are there materialization opportunities?
- Will availability calculation scale?
- Missing database tables or columns?

### 3. security-auditor
**Reviews**: BACKEND_ARCHITECTURE_DESIGN.md + DATABASE_ARCHITECTURE_PLAN.md
**Perspective**: "Where are the security gaps?"
**Attack Angle**: Find tenant isolation issues, authorization bypasses, data exposure risks
**Key Questions**:
- Is tenant_id filtering on EVERY query?
- Can staff see manager data? Actual costs?
- Are classifications enforced?
- Can users override approval workflows?
- SQL injection risks?

### 4. feature-dev:code-reviewer
**Reviews**: All specification documents
**Perspective**: "Is this testable and maintainable?"
**Attack Angle**: Find design patterns, testability issues, race conditions, code quality concerns
**Key Questions**:
- Can we test the velocity cascade end-to-end?
- Are there race conditions in approval workflow?
- Will tests run fast (< 5 min)?
- What's hardest to test?
- Are error cases handled properly?

### 5. performance-engineer
**Reviews**: All specification documents
**Perspective**: "Will this scale?"
**Attack Angle**: Find bottlenecks, O(n²) queries, resource exhaustion risks
**Key Questions**:
- What's the top query bottleneck?
- Will WebSocket connections scale to 1000+?
- Will bulk import handle 10K employees?
- Do we need caching layers?
- Core Web Vitals targets achievable?

### 6. ai-engineer
**Reviews**: ai-implementation-plan.md + BACKEND_ARCHITECTURE_DESIGN.md (EmployeeInfoService)
**Perspective**: "Will AI services work safely and reliably?"
**Attack Angle**: Find extraction edge cases, prompt injection risks, cost overruns
**Key Questions**:
- Can we prevent prompt injection attacks?
- Will classification masking work?
- How to handle malformed PDFs?
- Deduplication algorithm robust?
- Will Claude API costs be acceptable?

---

## Failure Handling

### If Critical Issues Found 🔴

**Status**: BLOCKED

**Actions**:
1. Stop Phase 1 launch
2. Categorize all issues:
   - P0: Must fix before Phase 1
   - P1: Must fix before Phase 2
   - P2: Schedule for Phase 6
3. Assign fixes to specialists
4. Re-review after fixes
5. Proceed only when all reviews pass

### If Concerns Found 🟡

**Status**: CONDITIONAL

**Actions**:
1. Document all concerns in TECHNICAL_DEBT.md
2. Proceed with Phase 1
3. Address during implementation
4. Re-review before Phase 2

### If Only Risks Found ⚠️

**Status**: APPROVED

**Actions**:
1. Document scalability considerations
2. Proceed with Phase 1
3. Plan for Phase 6 optimization
4. Add load testing for flagged areas

### All Clear ✅

**Status**: APPROVED

**Actions**:
1. Proceed with Phase 1 immediately
2. High confidence in architecture
3. Use findings as optimization guide for future phases

---

## Coordination Template

**Gauntlet Coordinator** orchestrates like this:

```
09:00 AM - PHASE 1: INITIALIZE
  ├─ Launch Task for feature-dev:backend-architect (database review)
  ├─ Launch Task for database-admin (services review)
  ├─ Launch Task for security-auditor (security review)
  ├─ Launch Task for feature-dev:code-reviewer (testability review)
  ├─ Launch Task for performance-engineer (scalability review)
  └─ Launch Task for ai-engineer (AI/integration review)

10:30 AM - PHASE 2: COLLECT REPORTS
  ├─ Receive backend-architect findings
  ├─ Receive database-admin findings
  ├─ Receive security-auditor findings
  ├─ Receive code-reviewer findings
  ├─ Receive performance-engineer findings
  └─ Receive ai-engineer findings

11:00 AM - PHASE 3: SYNTHESIZE FINDINGS
  ├─ Aggregate all critical issues
  ├─ Cross-reference (e.g., both backend + DBA mention same issue?)
  ├─ Identify false alarms
  ├─ Categorize by severity
  └─ Recommend go/no-go

11:30 AM - DECISION
  ├─ All clear? → Launch Phase 1 immediately
  ├─ Minor issues? → Document, proceed with Phase 1
  └─ Critical blockers? → Pause, fix, re-review
```

---

## Output Requirements

Each review task should return:

**DOCUMENT MUST INCLUDE**:
- Reviewer name and specialty
- Document(s) reviewed
- Timestamp
- CRITICAL ISSUES (if any)
- ARCHITECTURAL CONCERNS (if any)
- SCALABILITY RISKS (if any)
- TESTABILITY GAPS (if any)
- SUMMARY & RECOMMENDATION (✓/⚠️/✗)
- GO/NO-GO for Phase 1

**FORMAT**: Markdown, clear sections, evidence-based

---

## Success Criteria

**Gauntlet Review is Successful When**:
- ✅ All 6 reviews completed
- ✅ Critical issues identified and prioritized
- ✅ Concerns documented
- ✅ Go/no-go recommendation clear
- ✅ Phase 1 can proceed with confidence

**Review Quality Metrics**:
- Each review: 500+ words (thorough analysis)
- Evidence provided for each finding
- Specific recommendations given
- No "I think" statements (back with facts)

---

## Examples of Good Findings

**From backend-architect reviewing database schema**:
```
🔴 CRITICAL: Missing index on (tenant_id, employee_id, deleted_at)

Location: DATABASE_ARCHITECTURE_PLAN.md, Part 2, Table: employees

Description: The AvailabilityCalculator.getTeamCapacity() query joins employees to
employee_absences and filters by (tenant_id, employee_id) in the WHERE clause. Currently
indexed on (tenant_id, status, deleted_at) only. A scan of 100K employees will require
full table scan.

Query affected:
  SELECT SUM(available_hours) FROM employees e
  WHERE e.tenant_id = ? AND e.id IN (?) AND e.deleted_at IS NULL

Impact: With 100K employees, this query will scan 100K rows even when team size is 5.
At scale (1000 concurrent queries), database CPU will spike.

Recommendation: Add index: CREATE INDEX idx_employees_team_capacity
ON employees(tenant_id, id, deleted_at) WHERE deleted_at IS NULL;
```

**From security-auditor reviewing backend services**:
```
🔴 CRITICAL: Tenant isolation missing in DeduplicationDetector.findConflicts()

Location: BACKEND_ARCHITECTURE_DESIGN.md, Part 1, DeduplicationDetector service

Description: Line 234 searches for duplicate emails:
  const duplicates = await db.query(
    `SELECT * FROM employees WHERE email = ? AND deleted_at IS NULL`
  )

Missing: tenant_id filter. If two tenants have employees named john@example.com,
the service will flag cross-tenant duplicates.

Impact: CRITICAL - Staff from tenant-a could merge with data from tenant-b.
Full tenant isolation bypass.

Recommendation: Add tenant_id to query:
  WHERE email = ? AND tenant_id = ? AND deleted_at IS NULL
Verify: Search for all queries that process deduplication.
```

**From code-reviewer finding testability issue**:
```
🧪 GAP: VelocityOverrideResolver difficult to test end-to-end

Location: AGENT_TASK_ASSIGNMENT.md, Phase 3, "Velocity Integration Logic"

Description: Testing the full flow requires:
1. Create employee with base velocity 24
2. Create absence
3. Approve absence (triggers VelocityOverrideResolver)
4. Query sprint forecast (should show 19.2)
5. Query roadmap (should show rescheduled features)

This is 4 services + database + notification system. Hard to unit test, fragile to E2E test.

Test Challenge: If any service fails, hard to know which caused the problem.
Tests will be slow (multiple DB transactions). Setup/teardown complex.

Mitigation:
1. Extract velocity calculation into pure function (testable in isolation)
2. Mock ApprovalOrchestrator → VelocityOverrideResolver event
3. Create velocity-calculation.test.ts with unit tests
4. Create velocity-cascade.integration.test.ts with end-to-end
5. Add deterministic seed data

Risk if Not Addressed: Phase 6 E2E tests will fail mysteriously. Debugging will be painful.
```

---

## When to Use This Skill

✅ **Use For**:
- Pre-implementation specification reviews
- Architecture validation before coding
- Security/scalability spot-checks
- Testability assessment before development

❌ **Don't Use For**:
- Code reviews during implementation (use normal code-reviewer)
- Runtime debugging (use debugger agent)
- Performance profiling (use performance-engineer directly)

---

**Skill Version**: 1.0
**Status**: PRODUCTION READY
**Last Updated**: 2026-02-14

Load this skill with: `Skill({ skill: "gauntlet-review" })`
