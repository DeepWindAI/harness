# PM33 Harness Project Template

**Framework**: Anthropic's "Effective Harnesses for Long-Running Agents"
**Reference**: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

---

## Overview

A harness project is a structured approach for managing **long-running AI agent work** (16+ hours across 3+ sessions). It bridges the context gap between sessions through persistent state artifacts and deterministic setup.

**When to use a harness project**:
- ✅ Multi-phase features (3+ logical phases)
- ✅ Estimated 16+ hours of implementation
- ✅ Requires consistent, incremental progress across sessions
- ✅ Benefits from progress documentation and checkpoint management

**When NOT to use**:
- ❌ Single-session features (<8 hours total work)
- ❌ Features with unclear requirements
- ❌ One-off bug fixes or small enhancements

---

## Directory Structure

```
docs/frameworks/agent-state-{PROJECT-ID}/
├── README.md                          # Harness documentation (this file)
├── SPECIFICATION.md                   # Feature specification (reference to /docs/specs/)
├── pm33-agent-progress.json           # Structured feature checklist
├── claude-progress.txt                # Session-by-session log
├── init.sh                            # Environment initialization (quality gates)
├── pre-commit-validation.sh           # Pre-commit validation gates
└── [optional] validation-tests/       # Project-specific E2E tests
```

---

## File Specifications

### 1. README.md

**Purpose**: Harness documentation for developers and agents

**Sections**:
```markdown
# PROJECT-NAME: Feature Description
## Long-Running Agent Harness Instance

**Framework**: [Anthropic's Effective Harnesses...](link)
**Task ID**: PROJECT-ID
**Priority**: P[1-3]
**Total Features**: N across M phases
**Estimated Hours**: X-Y hours

---

## Overview
[Brief description of what this harness implements]

## Harness Structure
[Directory layout + key files]

### Feature Breakdown (N Features)
#### Phase X: Phase Name (Xh)
- **FEAT-001**: Description
- **FEAT-002**: Description

## Usage
### Quick Start
[Copy-paste commands to start work]

### Starting a New Coding Session
[Step-by-step session startup checklist]

### Quality Gates Overview
[Init gates (X gates) vs Pre-commit gates (Y gates)]

### TDD Workflow
[RED-GREEN-REFACTOR-DELIVERY cycle]

## Baseline Validation
[What was validated before starting]

## Next Steps
[Current state + what's next]

## Success Criteria
[How we know this is complete]

## Risk Mitigation
[Known risks + mitigation strategies]
```

### 2. pm33-agent-progress.json

**Purpose**: Structured feature checklist for tracking progress

**Schema**:
```json
{
  "workflowName": "PROJECT-NAME: Feature Description",
  "workflowType": "feature_type",
  "taskId": "PROJECT-ID",
  "sessionId": "project-id-init",
  "totalFeatures": 18,
  "completed": 3,
  "inProgress": 0,
  "pending": 15,
  "features": [
    {
      "id": "FEAT-001",
      "name": "Feature Name",
      "description": "What this feature does",
      "phase": "Phase X: Phase Name",
      "status": "completed|in_progress|pending",
      "isUIFeature": false,
      "isBackendFeature": true,
      "estimatedHours": 3,
      "requiredPRDSections": [
        "/docs/specs/PROJECT_SPECIFICATION.md:100-120",
        "/docs/specs/PROJECT_SPECIFICATION.md:156-173"
      ],
      "wireframeReferences": [
        {
          "file": "/docs/current/design/PM33_WIREFRAMES_v14.md",
          "lines": "XXX-YYY",
          "section": "Feature Section Name"
        }
      ],
      "apiContracts": [
        "/server/contracts/project.contract.ts"
      ],
      "validationCriteria": [
        "Specific acceptance criterion 1",
        "Specific acceptance criterion 2"
      ],
      "passedTests": [
        "Test case 1",
        "Test case 2"
      ],
      "evidenceLinks": [
        "/path/to/implementation.ts",
        "/path/to/test.ts"
      ],
      "gitCommit": "abc1234",
      "checkpointId": null,
      "contextValidation": {
        "passed": true,
        "filesRead": [
          "/docs/specs/...",
          "/server/..."
        ],
        "minimumFilesRequired": 3
      },
      "tddPhases": {
        "red": { "completed": true, "testFile": "/path/to/test.ts" },
        "green": { "completed": true, "qualityGatesPassed": true },
        "refactor": { "completed": true, "iterations": 1 },
        "delivery": { "completed": true, "evidenceCollected": true }
      },
      "startedAt": "2025-12-06T20:11:00Z",
      "completedAt": "2025-12-07T01:30:00Z"
    }
  ],
  "blockers": [],
  "technicalDebt": [],
  "baselineValidation": {
    "schemaDrift": "✅ RESOLVED",
    "typeScriptCompilation": "✅ Clean",
    "eslintValidation": "⚠️ Baseline documented",
    "unitTests": "⚠️ Baseline documented",
    "integrationTests": "⚠️ Baseline documented",
    "e2eInfrastructure": "✅ Verified",
    "databaseSchema": "✅ No changes required",
    "conclusion": "✅ Ready for implementation"
  },
  "nextSession": {
    "featureId": "FEAT-004",
    "estimatedHours": 3,
    "prerequisites": [
      "Service X exists at /server/services/x.ts",
      "Contract Y defined in /server/contracts/y.ts"
    ]
  },
  "createdAt": "2025-12-06T00:00:00Z",
  "updatedAt": "2025-12-06T00:00:00Z"
}
```

### 3. claude-progress.txt

**Purpose**: Human-readable session log

**Format**:
```
=== SESSION YYYY-MM-DDTHH:MM:SSZ ===
Feature: FEAT-XXX: Feature Name
Status: ✅ COMPLETED | 🚧 IN PROGRESS | ❌ BLOCKED

Context Reading Validation: ✅ PASSED
  ✅ Read: /docs/specs/...
  ✅ Read: /server/...

TDD Phases Completed:

1. RED PHASE: ✅ COMPLETE
   Test File: /path/to/test.ts (N lines)
   Test Count: X test cases covering:
     - Test category 1
     - Test category 2

2. GREEN PHASE: ✅ COMPLETE
   Implementation: /path/to/implementation.ts (N lines)
   Details: ...

3. REFACTOR PHASE: ✅ COMPLETE
   Actions:
     ✅ Code quality improvements
     ✅ JSDoc documentation

4. DELIVERY PHASE: ✅ COMPLETE
   Validation Gates: Y/Y PASSED ✅
   Evidence: [links to files]

Progress Tracking Updates:
  ✅ pm33-agent-progress.json: Updated
  ✅ TDD phases marked complete
  ✅ Feature completion timestamp: ...

Next Feature: FEAT-XXX (Name)
Estimated Hours: X
Status: Ready

=====================================
```

### 4. init.sh

**Purpose**: Deterministic environment initialization with quality gates

**Key sections**:
```bash
#!/bin/bash
# PM33 Agent Environment Initialization
# PROJECT-ID: Feature Description
# Framework: /docs/frameworks/LONG_RUNNING_AGENT_FRAMEWORK.md

set -e

# 1. Verify project root
# 2. Verify OrbStack services running
# 3-N. Quality gates:
#    - Schema Drift Validation
#    - TypeScript Compilation
#    - ESLint Validation
#    - API Contract Compliance
#    - Critical Tests
#    - Project-specific baseline
```

### 5. pre-commit-validation.sh

**Purpose**: Pre-commit validation gates (blocks on critical failures)

**Example gates**:
```bash
# Gate 1: Schema Drift Validation
# Gate 2: TypeScript Compilation
# Gate 3: ESLint Validation (new code only)
# Gate 4: Zod Contract Validation
# Gate 5: Unit Test Coverage (>95%)
# Gate 6: Integration Tests (100% pass)
# Gate 7: E2E Tests (100% pass)
# Gate 8: API Interface Validation
# Gate 9: Documentation Completeness
# Gate 10: Progress Tracking (harness files)
```

---

## Session Checklist

### Starting a New Session

```bash
# 1. Navigate to project root
cd /Users/ssaper/Developer/pm-33-core

# 2. Run environment initialization (once per session)
./docs/frameworks/agent-state-{PROJECT-ID}/init.sh

# 3. Verify all quality gates pass
# 4. Read last 3 sessions from claude-progress.txt
# 5. Check git log for recent commits
# 6. Load feature status from pm33-agent-progress.json
# 7. Select SINGLE feature (no multi-feature sessions)
# 8. Read required PRD sections (minimum 3 files)
```

### Implementing a Feature (TDD Cycle)

```bash
# RED PHASE: Write test first (expect failure)
# - Create test file in /server/__tests__/ or /tests/e2e/
# - Document expected failure in claude-progress.txt
# - Verify test fails for the right reason

# GREEN PHASE: Implement minimal code
# - Create implementation file
# - Run pre-commit validation
# - Verify test now passes

# REFACTOR PHASE: Clean up code
# - Remove duplication, dead code, unused imports
# - Re-run validation after each iteration
# - Ensure all tests still pass

# DELIVERY PHASE: Collect evidence
# - Run final validation: ./pre-commit-validation.sh
# - Collect evidence (test coverage, performance, etc.)
# - Update pm33-agent-progress.json
# - Append session log to claude-progress.txt
# - Git commit with detailed message
```

### Completing a Session

```bash
# Before ending session:

1. Update pm33-agent-progress.json
   - Change status to "completed"
   - Update completion timestamp
   - Add git commit hash
   - Update feature counter

2. Append session log to claude-progress.txt
   - Document all 4 TDD phases
   - Include validation results
   - Note any technical debt discovered

3. Commit to git
   git add docs/frameworks/agent-state-{PROJECT-ID}/
   git commit -m "FEAT-XXX: Description - All validation gates PASSED"

4. Document any issues
   - Add to TECHNICAL_DEBT.md if architectural issues found
   - Create follow-up tasks if blockers discovered
```

---

## Quality Gates

### Initialization Gates (init.sh)

| Gate | Purpose | Failure Behavior |
|------|---------|-----------------|
| Schema Drift | Ensure schema.ts matches database | ❌ BLOCKS initialization |
| TypeScript | Validate type safety | ⚠️ WARNING (running app validates) |
| ESLint | Code quality baseline | ⚠️ WARNING (pre-existing) |
| API Contracts | Zod contract compliance | ❌ BLOCKS if violations |
| Critical Tests | Core functionality | ❌ BLOCKS if failing |
| Project Baseline | Project-specific validation | ❌ BLOCKS if requirements unmet |

### Pre-Commit Gates (pre-commit-validation.sh)

| Gate | Purpose | Failure Behavior |
|------|---------|-----------------|
| Schema Drift | Zero schema drift in changes | ❌ BLOCKS commit |
| TypeScript | 0 new TypeScript errors | ❌ BLOCKS commit |
| ESLint | 0 errors in new code | ❌ BLOCKS commit |
| Unit Tests | >95% coverage for services | ✓ Must pass |
| Integration Tests | 100% pass rate | ✓ Must pass |
| E2E Tests | 100% pass rate | ✓ Must pass |
| API Validation | Zod contract compliance | ✓ Must pass |
| Documentation | JSDoc comments on services | ✓ Must pass |
| Progress Tracking | Harness files valid/updated | ✓ Must pass |
| Context Reading | Required docs read | ✓ Must pass |

---

## Best Practices

### ✅ DO

- **One feature per session**: Avoid multi-feature attempts
- **Read context first**: Always read minimum 3 required documentation files before starting
- **Write tests first (RED)**: TDD discipline with visible test failures
- **Commit incrementally**: One feature = one commit with detailed message
- **Update progress tracking**: Maintain claude-progress.txt session log
- **Document blockers**: Add to TECHNICAL_DEBT.md if architectural issues found
- **Use quality gates**: Pre-commit validation MUST pass before committing

### ❌ DON'T

- **Attempt multiple features**: Single feature per session maintains focus
- **Skip TDD cycle**: RED-GREEN-REFACTOR-DELIVERY is mandatory
- **Ignore validation failures**: All critical gates must pass
- **Hardcode values**: Use environment variables, configuration objects
- **Add mock data**: Use real data integration with proper empty states
- **Skip documentation**: JSDoc comments required on all services
- **Leave console.logs**: Production-ready code only

---

## Templates for Copy-Paste

### Feature Entry (pm33-agent-progress.json)

```json
{
  "id": "FEAT-XXX",
  "name": "Feature Name",
  "description": "What this feature does",
  "phase": "Phase X: Phase Name",
  "status": "pending",
  "isUIFeature": false,
  "isBackendFeature": true,
  "estimatedHours": 3,
  "requiredPRDSections": [
    "/docs/specs/PROJECT_SPECIFICATION.md:100-120"
  ],
  "wireframeReferences": [],
  "apiContracts": [],
  "validationCriteria": [
    "Specific acceptance criterion 1"
  ],
  "passedTests": null,
  "evidenceLinks": [],
  "gitCommit": null,
  "checkpointId": null,
  "contextValidation": {
    "passed": false,
    "filesRead": [],
    "minimumFilesRequired": 3
  },
  "tddPhases": {
    "red": { "completed": false, "testFile": null },
    "green": { "completed": false, "qualityGatesPassed": false },
    "refactor": { "completed": false, "iterations": 0 },
    "delivery": { "completed": false, "evidenceCollected": false }
  },
  "startedAt": null,
  "completedAt": null
}
```

### Session Log Entry (claude-progress.txt)

```
=== FEAT-XXX IMPLEMENTATION SESSION YYYY-MM-DDTHH:MM:SSZ ===
Feature: FEAT-XXX: Feature Name
Status: IN PROGRESS

Context Reading Validation: ✅ PASSED
  ✅ Read: /docs/specs/...

TDD Phases:

1. RED PHASE: ✅ COMPLETE
   Test File: /path/to/test.ts

2. GREEN PHASE: ✅ COMPLETE
   Implementation: /path/to/implementation.ts

3. REFACTOR PHASE: ⏳ IN PROGRESS

4. DELIVERY PHASE: ⏳ PENDING

Next: FEAT-XXX (Name)

=====================================
```

---

## Examples

**Complete examples**:
- UTT-STRAT-001 (Competitive Discovery): `/docs/frameworks/agent-state-utt-strat-001/`
- Base Framework: `/docs/frameworks/LONG_RUNNING_AGENT_FRAMEWORK.md`

---

## FAQ

**Q: When should I create a harness project?**
A: When work spans 16+ hours across 3+ sessions with clear feature phases. Use harness projects for major features (competitive discovery, PRD generation, backlog optimization).

**Q: Can I work on multiple features in one session?**
A: No. One feature per session maintains focus and produces clean, mergeable code. Multi-feature attempts cause context loss.

**Q: What if a feature takes longer than estimated?**
A: Update the estimate in pm33-agent-progress.json and continue in next session. Document blockers in TECHNICAL_DEBT.md.

**Q: How do I handle failed validation gates?**
A: Don't commit if critical gates fail. Fix the issue, re-run validation, then commit. All gates must pass before merging.

**Q: What about context between sessions?**
A: Read claude-progress.txt (last 3 sessions) + pm33-agent-progress.json + git log. Run init.sh to verify environment. This is the startup ritual.
