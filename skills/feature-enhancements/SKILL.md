---
name: feature-enhancements
description: Review pending feature enhancements, assess implementation readiness, check design completeness, and identify what's ready to build. Use when planning sprint work or reviewing the feature pipeline.
user_invocable: true
---

# Feature Enhancements Review Skill

**Purpose**: Review the pending feature enhancements registry, assess readiness for implementation, identify gaps, and recommend next steps.

---

## When to Use

- User asks to review pending features / enhancements
- Sprint planning — deciding what to pull into upcoming work
- Checking if a design is complete enough to start implementation
- Periodic review of the feature pipeline
- User says "review enhancements", "what features are pending", "what's ready to build"

---

## Workflow

### Step 1: Load the Registry

Read the feature enhancements registry:

```
Read: docs/design/PENDING_FEATURE_ENHANCEMENTS.md
```

### Step 2: For Each Enhancement, Assess Readiness

For each entry with status `APPROVED` or `DESIGN`, evaluate:

**Design Completeness** (read the linked design doc):
- [ ] Problem statement clear?
- [ ] Formula / algorithm defined?
- [ ] Data sources identified and verified to exist?
- [ ] Service interface (TypeScript types) defined?
- [ ] Consumer integration points listed?
- [ ] Implementation phasing with effort estimates?
- [ ] Open questions documented?
- [ ] Key decisions logged with rationale?

**Infrastructure Readiness** (check codebase):
- [ ] Required database tables exist? (check `shared/schema/`)
- [ ] Required services exist to extend? (check `server/services/`)
- [ ] Required contracts exist to extend? (check `server/contracts/`)
- [ ] Test infrastructure ready?

**Dependency Check**:
- [ ] No blocking dependencies?
- [ ] All "Existing" dependencies verified in codebase?
- [ ] "New" dependencies scoped and estimated?

### Step 3: Generate Readiness Report

For each enhancement, output:

```
### [ID]: [Name]
**Status**: [current status]
**Readiness**: [READY | NEEDS WORK | BLOCKED]
**Design Score**: [X/8 completeness checks]
**Infrastructure Score**: [X/4 readiness checks]

**What's Ready**:
- [list of ready items]

**What's Missing**:
- [list of gaps]

**Recommended Next Step**:
- [specific action: "Start Phase 1" or "Need to resolve open question #3 first"]

**Estimated Start**: [can start now | needs N days of prep]
```

### Step 4: Prioritization Recommendation

If multiple enhancements are READY, recommend order based on:
1. **Blocking value** — does this unblock other features?
2. **Consumer demand** — how many consumers need this?
3. **Data availability** — can we use real data from day 1?
4. **Effort-to-value ratio** — quick wins vs. large builds

---

## Verification Patterns

### Check if database table exists
```bash
grep -r "table_name" shared/schema/ --include="*.ts" -l
```

### Check if service exists
```bash
ls server/services/ | grep -i "ServiceName"
```

### Check if contract exists
```bash
ls server/contracts/ | grep -i "feature-name"
```

### Check if design doc is complete
```bash
# Look for key sections
grep -c "## " docs/design/FEATURE_DESIGN.md
# Should have: Problem, Formula, Data Sources, Interface, Consumers, Phasing, Decisions
```

---

## Output Format

Always conclude with a summary table:

```
| ID | Enhancement | Status | Readiness | Design | Infra | Next Step |
|----|------------|--------|-----------|--------|-------|-----------|
| PVS-001 | Planning Velocity | APPROVED | READY | 8/8 | 4/4 | Start Phase 1 |
```

---

## Related Files

- **Registry**: `docs/design/PENDING_FEATURE_ENHANCEMENTS.md`
- **Design docs**: `docs/design/*.md`
- **Technical debt**: `docs/reference/TECHNICAL_DEBT.md`
- **UTT**: `PM33_UNIFIED_TASK_TRACKER.md`
