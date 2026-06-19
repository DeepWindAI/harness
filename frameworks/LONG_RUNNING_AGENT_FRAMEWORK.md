# PM33 Long-Running Agent Framework
## Based on Anthropic's "Effective Harnesses for Long-Running Agents"

**Status**: ✅ APPROVED - IMPLEMENTATION READY
**Created**: 2025-12-06
**Framework Source**: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

---

## Executive Summary

This framework applies Anthropic's proven patterns for long-running AI agents to PM33's workflows:
- **Competitive Discovery** (multi-session competitor analysis)
- **Strategy Analysis** (iterative website extraction + consolidation)
- **PRD Generation** (progressive refinement with user feedback)
- **Backlog Optimization** (framework-based prioritization)

**Core Principle**: Decompose long-running work into **Initializer + Coding sessions** with persistent, human-readable state artifacts (progress files, git commits, structured JSON).

---

## 1. Framework Architecture

### 1.1 Two-Phase Agent Pattern

```
┌─────────────────────────────────────────────────────────────┐
│ PHASE 1: INITIALIZER AGENT (First Session)                  │
├─────────────────────────────────────────────────────────────┤
│ - Create pm33-agent-progress.json (feature checklist)       │
│ - Initialize claude-progress.txt (session log)              │
│ - Set up validation tests (E2E browser automation)          │
│ - Create initial git commit with baseline state             │
│ - Execute init.sh (start dev environment)                   │
│ - Validate baseline functionality                           │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ PHASE 2: CODING AGENT (Subsequent Sessions)                 │
├─────────────────────────────────────────────────────────────┤
│ 1. Read claude-progress.txt (last 3 sessions)               │
│ 2. Check git log (recent commits)                           │
│ 3. Load pm33-agent-progress.json (feature status)           │
│ 4. Run init.sh (verify environment)                         │
│ 5. Execute validation tests (detect regressions)            │
│ 6. SELECT SINGLE FEATURE from pending list                  │
│ 7. Implement incrementally with E2E testing                 │
│ 8. Git commit with descriptive message                      │
│ 9. Update claude-progress.txt + feature status              │
│ 10. End session (no multi-feature attempts)                 │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 State Artifact Structure

**File Locations**:
```
/docs/frameworks/agent-state/
├── claude-progress.txt              # Session-by-session log
├── pm33-agent-progress.json         # Structured feature checklist
├── init.sh                          # Deterministic environment startup
└── validation-tests/
    ├── competitive-discovery.e2e.ts
    ├── strategy-analysis.e2e.ts
    └── prd-generation.e2e.ts
```

**claude-progress.txt Format**:
```
=== SESSION 2025-12-06T10:30:00Z ===
Feature: Competitive Discovery - Phase 1 (Company Analysis)
Status: ✅ COMPLETED
Changes:
- Created CompetitiveDiscoveryPanel.tsx with 4-phase state machine
- Added DiscoveryProgressIndicator.tsx with WebSocket connection
- Database migration: competitors table with extraction_status enum
- API endpoint: POST /api/competitors/discovery/start
Validation: ✅ E2E test passed (discovery-start-workflow.spec.ts)
Git Commit: abc1234 "feat: Add Competitive Discovery Phase 1"
Next Session: Implement Phase 2 (Competitor Identification via AI)

=== SESSION 2025-12-06T14:15:00Z ===
Feature: Competitive Discovery - Phase 2 (AI Competitor ID)
Status: 🚧 IN PROGRESS
...
```

**pm33-agent-progress.json Format**:
```json
{
  "workflowName": "Competitive Discovery Integration",
  "totalFeatures": 42,
  "completed": 8,
  "inProgress": 1,
  "pending": 33,
  "features": [
    {
      "id": "CD-001",
      "name": "Company Analysis - Extract Your Differentiators",
      "status": "completed",
      "validationCriteria": [
        "UI shows extracted differentiators from strategy sources",
        "Confidence scores visible for each differentiator",
        "User can edit/refine differentiators before discovery",
        "E2E test: Click 'Start Discovery' → See Phase 1 complete"
      ],
      "passedTests": true,
      "gitCommit": "abc1234",
      "completedAt": "2025-12-06T11:00:00Z"
    },
    {
      "id": "CD-002",
      "name": "Competitor Identification - AI Discovery",
      "status": "in_progress",
      "validationCriteria": [
        "AI uses YOUR differentiators to find THEIR competitors",
        "Top 5 competitors identified automatically",
        "Prioritize mentioned competitors (0.95 confidence)",
        "Discovery progress visible via WebSocket updates"
      ],
      "passedTests": false,
      "gitCommit": null,
      "startedAt": "2025-12-06T14:15:00Z"
    },
    {
      "id": "CD-003",
      "name": "Competitor Analysis - Website Extraction",
      "status": "pending",
      "validationCriteria": [
        "Reuse existing website extraction service",
        "Extract competitor differentiators, pricing, features",
        "Parallel extraction for top 5 competitors",
        "Store in competitors table with extractedData JSONB"
      ],
      "passedTests": null
    }
    // ... 39 more features
  ],
  "blockers": [],
  "technicalDebt": [],
  "nextSession": {
    "featureId": "CD-002",
    "estimatedHours": 3,
    "prerequisites": ["AI service contract", "WebSocket connection tested"]
  }
}
```

**init.sh Script** (Enhanced with PM33 Quality Gates):
```bash
#!/bin/bash
# PM33 Long-Running Agent Environment Initialization
# Enforces: TDD, Schema Validation, ESLint, Contract Compliance

set -e

echo "🚀 PM33 Agent Environment Init"
echo "================================"

# 1. Verify we're in project root
if [ ! -f "package.json" ]; then
  echo "❌ ERROR: Not in PM33 project root"
  exit 1
fi

# 2. Start OrbStack development environment
echo "📦 Starting OrbStack containers..."
docker-compose -f docker-compose.dev.yml up -d --quiet-pull 2>/dev/null

# 3. Wait for services to be healthy
echo "⏳ Waiting for PostgreSQL (port 5433)..."
timeout 30 bash -c 'until pg_isready -h localhost -p 5433 -U pm33 > /dev/null 2>&1; do sleep 1; done' || {
  echo "❌ PostgreSQL failed to start"
  exit 1
}

echo "⏳ Waiting for Redis (port 6380)..."
timeout 30 bash -c 'until redis-cli -h localhost -p 6380 ping > /dev/null 2>&1; do sleep 1; done' || {
  echo "❌ Redis failed to start"
  exit 1
}

echo "⏳ Waiting for App (port 5001)..."
timeout 60 bash -c 'until curl -s http://localhost:5001/api/health > /dev/null 2>&1; do sleep 2; done' || {
  echo "❌ App failed to start"
  exit 1
}

# 4. Run database migrations
echo "🗄️  Running database migrations..."
npm run db:migrate:dev --silent || {
  echo "❌ Database migrations failed"
  exit 1
}

# 5. PM33 QUALITY GATE 1: Schema Drift Validation
echo "🔍 [QUALITY GATE 1] Schema Drift Validation..."
npm run validate:schema-drift --silent || {
  echo "❌ BLOCKED: Schema drift detected"
  echo "   Run: npm run validate:schema-drift"
  echo "   Fix: Sync shared/schema.ts with database migrations"
  exit 1
}
echo "   ✅ No schema drift detected"

# 6. PM33 QUALITY GATE 2: TypeScript Compilation
echo "🔍 [QUALITY GATE 2] TypeScript Compilation..."
npx tsc --noEmit --skipLibCheck || {
  echo "❌ BLOCKED: TypeScript compilation errors"
  exit 1
}
echo "   ✅ TypeScript compilation clean"

# 7. PM33 QUALITY GATE 3: ESLint Validation
echo "🔍 [QUALITY GATE 3] ESLint Validation..."
npm run lint --silent || {
  echo "❌ BLOCKED: ESLint errors detected"
  echo "   Run: npm run lint"
  echo "   Fix: Address all ESLint errors before proceeding"
  exit 1
}
echo "   ✅ ESLint validation passed"

# 8. PM33 QUALITY GATE 4: API Contract Compliance
echo "🔍 [QUALITY GATE 4] API Contract Compliance..."
npm run api:validate:pre-change --silent || {
  echo "❌ BLOCKED: API contract violations detected"
  echo "   Run: npm run api:validate:pre-change"
  echo "   Fix: Update Zod contracts in /server/contracts/"
  exit 1
}
echo "   ✅ API contracts compliant"

# 9. PM33 QUALITY GATE 5: Test Suite Validation
echo "🔍 [QUALITY GATE 5] Running Test Suite..."
npm run test:critical --silent || {
  echo "❌ BLOCKED: Critical tests failing"
  echo "   Run: npm run test:critical"
  echo "   Fix: All tests must pass before proceeding"
  exit 1
}
echo "   ✅ Critical tests passing"

# 10. PM33 QUALITY GATE 6: Delivery Pre-Task Validation
echo "🔍 [QUALITY GATE 6] Delivery Validation..."
npm run validate:delivery:pre-task --silent || {
  echo "⚠️  Validation warnings (non-blocking)"
}
echo "   ✅ Baseline metrics established"

echo ""
echo "✅ Environment Ready - All Quality Gates Passed"
echo "   - PostgreSQL: localhost:5433"
echo "   - Redis: localhost:6380"
echo "   - App: http://localhost:5001"
echo "   - Database: pm33_development"
echo "   - Schema Drift: ✅ Clean"
echo "   - TypeScript: ✅ Compiled"
echo "   - ESLint: ✅ Passed"
echo "   - Contracts: ✅ Compliant"
echo "   - Tests: ✅ Passing"
echo ""
```

---

## 1.3 PM33 Test-Driven Development (TDD) Workflow

**MANDATORY**: All features MUST follow Red-Green-Refactor discipline with context reading enforcement.

### TDD Cycle Integration with Long-Running Agents

```
┌──────────────────────────────────────────────────────────────────┐
│ STEP 1: CONTEXT READING (MANDATORY - BLOCKING)                   │
├──────────────────────────────────────────────────────────────────┤
│ Agent MUST read ALL relevant documentation BEFORE writing code:  │
│ - Feature specification from pm33-agent-progress.json            │
│ - Relevant PRD sections (domain/*.md)                            │
│ - Related wireframes (/docs/current/design/PM33_WIREFRAMES_v14)  │
│ - API contracts (/server/contracts/*.contract.ts)                │
│ - Database schema (shared/schema.ts + recent migrations)         │
│ - Existing implementation files (if modifying)                   │
│                                                                   │
│ ❌ BLOCKED: Cannot proceed without reading context               │
│ ✅ VALIDATION: Log context files read to progress.txt            │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ STEP 2: RED - Write Failing Test FIRST                           │
├──────────────────────────────────────────────────────────────────┤
│ 1. Create E2E test based on validation criteria                  │
│ 2. Run test → Expect FAILURE (feature not implemented)           │
│ 3. Checkpoint: "red-phase-{featureId}" with test file            │
│ 4. Document expected behavior in progress.txt                    │
│                                                                   │
│ ❌ BLOCKED: Test must fail before implementation                 │
│ ✅ VALIDATION: npm run test:critical shows failing test          │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ STEP 3: GREEN - Implement Minimal Code to Pass Test              │
├──────────────────────────────────────────────────────────────────┤
│ 1. Write ONLY enough code to make test pass                      │
│ 2. Run quality gates CONTINUOUSLY:                               │
│    - TypeScript compilation (npx tsc --noEmit)                   │
│    - ESLint validation (npm run lint)                            │
│    - Schema drift check (npm run validate:schema-drift)          │
│    - Contract compliance (npm run api:test:contracts)            │
│ 3. Run test → Expect SUCCESS                                     │
│ 4. Checkpoint: "green-phase-{featureId}" with implementation     │
│                                                                   │
│ ❌ BLOCKED: Quality gates must pass before checkpoint            │
│ ✅ VALIDATION: All quality gates + test passing                  │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ STEP 4: REFACTOR - Clean Up Code While Maintaining Tests         │
├──────────────────────────────────────────────────────────────────┤
│ 1. Improve code quality (remove duplication, extract functions)  │
│ 2. Run quality gates AFTER each refactor:                        │
│    - Ensure tests still pass                                     │
│    - No new ESLint errors                                        │
│    - No schema drift introduced                                  │
│    - Contracts remain compliant                                  │
│ 3. Final checkpoint: "refactor-complete-{featureId}"             │
│                                                                   │
│ ❌ BLOCKED: Refactor breaks tests or quality gates               │
│ ✅ VALIDATION: Tests passing + quality gates clean               │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────────┐
│ STEP 5: DELIVERY VALIDATION - Final Quality Assurance            │
├──────────────────────────────────────────────────────────────────┤
│ 1. Run complete delivery validation:                             │
│    npm run validate:delivery:complete                            │
│ 2. Evidence collection:                                          │
│    - Test coverage report (>95% for new code)                    │
│    - Performance audit (Core Web Vitals)                         │
│    - Accessibility audit (WCAG 2.1 AA)                           │
│    - Visual compliance (wireframe match)                         │
│ 3. Update pm33-agent-progress.json:                              │
│    - Feature status: "completed"                                 │
│    - passedTests: true                                           │
│    - evidenceLinks: [coverage, performance, a11y, visual]        │
│                                                                   │
│ ✅ VALIDATION: All evidence collected + feature complete         │
└──────────────────────────────────────────────────────────────────┘
```

### Context Reading Enforcement

**MANDATORY PRE-WORK CHECKLIST** (Logged to progress.txt):

```typescript
// /server/services/competitive-discovery/CompetitiveDiscoveryOrchestrator.ts

async executeFeatureWithContextValidation(
  sessionId: string,
  featureId: string
): Promise<FeatureResult> {

  // 1. MANDATORY: Load feature requirements
  const feature = await this.loadFeatureRequirements(sessionId, featureId);

  // 2. MANDATORY: Document context reading
  const contextLog = {
    featureId,
    contextFilesRead: [],
    readTimestamps: {},
    validationPassed: false
  };

  // 3. MANDATORY: Read ALL required documentation
  logger.info(`[CONTEXT READING] Feature ${featureId}: ${feature.name}`);

  // 3a. PRD sections
  const prdSections = feature.requiredPRDSections || [];
  for (const section of prdSections) {
    const content = await this.readFile(section);
    contextLog.contextFilesRead.push(section);
    contextLog.readTimestamps[section] = new Date().toISOString();
    logger.info(`  ✅ Read: ${section}`);
  }

  // 3b. Wireframes
  if (feature.wireframeReferences) {
    for (const wireframe of feature.wireframeReferences) {
      const content = await this.readFile(wireframe.file);
      contextLog.contextFilesRead.push(wireframe.file);
      logger.info(`  ✅ Read: ${wireframe.file} (lines ${wireframe.lines})`);
    }
  }

  // 3c. API Contracts
  if (feature.apiContracts) {
    for (const contract of feature.apiContracts) {
      const content = await this.readFile(`/server/contracts/${contract}`);
      contextLog.contextFilesRead.push(`/server/contracts/${contract}`);
      logger.info(`  ✅ Read: /server/contracts/${contract}`);
    }
  }

  // 3d. Database Schema
  const schemaContent = await this.readFile('/shared/schema.ts');
  contextLog.contextFilesRead.push('/shared/schema.ts');
  logger.info(`  ✅ Read: /shared/schema.ts`);

  // 3e. Recent migrations
  const recentMigrations = await this.getRecentMigrations(30); // Last 30 days
  for (const migration of recentMigrations) {
    const content = await this.readFile(migration.file);
    contextLog.contextFilesRead.push(migration.file);
    logger.info(`  ✅ Read: ${migration.file}`);
  }

  // 4. VALIDATION: Ensure minimum context requirements met
  const minimumFilesRequired = 3; // At minimum: PRD + Wireframe + Contract
  if (contextLog.contextFilesRead.length < minimumFilesRequired) {
    throw new Error(
      `CONTEXT VALIDATION FAILED: Only ${contextLog.contextFilesRead.length} files read, minimum ${minimumFilesRequired} required`
    );
  }

  contextLog.validationPassed = true;

  // 5. Log context reading to progress.txt
  const progressUpdate = `
[CONTEXT READING COMPLETE] Feature ${featureId}
Files Read: ${contextLog.contextFilesRead.length}
${contextLog.contextFilesRead.map(f => `  - ${f}`).join('\n')}
Validation: ✅ PASSED
`;
  await this.appendProgressArtifact(sessionId, 'progress.txt', progressUpdate);

  // 6. NOW proceed with TDD cycle
  return await this.executeTDDCycle(sessionId, feature, contextLog);
}
```

### TDD Cycle Implementation

```typescript
async executeTDDCycle(
  sessionId: string,
  feature: Feature,
  contextLog: ContextLog
): Promise<FeatureResult> {

  // ═══════════════════════════════════════════════════════════
  // PHASE 1: RED - Write Failing Test
  // ═══════════════════════════════════════════════════════════

  logger.info(`[TDD - RED] Writing failing test for ${feature.id}`);

  // Create E2E test based on validation criteria
  const testFile = await this.createE2ETest(feature);

  // Run test - MUST fail
  const redResult = await this.runTests(testFile);
  if (redResult.passed) {
    throw new Error(
      `TDD RED PHASE FAILED: Test passed before implementation (indicates test not testing the right thing)`
    );
  }

  // Checkpoint: Red phase
  await this.createCheckpoint(sessionId, 'red_phase', {
    featureId: feature.id,
    testFile,
    expectedFailure: redResult.error
  });

  logger.info(`  ✅ RED: Test failing as expected`);

  // ═══════════════════════════════════════════════════════════
  // PHASE 2: GREEN - Implement Minimal Code
  // ═══════════════════════════════════════════════════════════

  logger.info(`[TDD - GREEN] Implementing minimal code for ${feature.id}`);

  // Implement feature
  const implementation = await this.implementFeature(feature);

  // CONTINUOUS QUALITY GATES (run after each file change)
  await this.runContinuousValidation(sessionId);

  // Run test - MUST pass
  const greenResult = await this.runTests(testFile);
  if (!greenResult.passed) {
    // Rollback to red checkpoint
    await this.rollbackToCheckpoint(sessionId, 'red_phase');
    throw new Error(
      `TDD GREEN PHASE FAILED: Implementation didn't make test pass: ${greenResult.error}`
    );
  }

  // Checkpoint: Green phase
  await this.createCheckpoint(sessionId, 'green_phase', {
    featureId: feature.id,
    implementation,
    testPassing: true
  });

  logger.info(`  ✅ GREEN: Test passing`);

  // ═══════════════════════════════════════════════════════════
  // PHASE 3: REFACTOR - Clean Up Code
  // ═══════════════════════════════════════════════════════════

  logger.info(`[TDD - REFACTOR] Cleaning up code for ${feature.id}`);

  // Iterative refactoring
  let refactorAttempts = 0;
  while (refactorAttempts < 3) { // Max 3 refactor iterations
    const refactorSuggestions = await this.identifyRefactorOpportunities(implementation);

    if (refactorSuggestions.length === 0) break;

    await this.applyRefactoring(refactorSuggestions[0]);

    // CONTINUOUS QUALITY GATES
    await this.runContinuousValidation(sessionId);

    // Ensure tests still pass
    const refactorResult = await this.runTests(testFile);
    if (!refactorResult.passed) {
      // Rollback refactor
      await this.rollbackToCheckpoint(sessionId, 'green_phase');
      logger.warn(`  ⚠️  Refactor broke tests, rolled back`);
      break;
    }

    refactorAttempts++;
  }

  // Final checkpoint: Refactor complete
  await this.createCheckpoint(sessionId, 'refactor_complete', {
    featureId: feature.id,
    refactorIterations: refactorAttempts
  });

  logger.info(`  ✅ REFACTOR: Code cleaned up (${refactorAttempts} iterations)`);

  // ═══════════════════════════════════════════════════════════
  // PHASE 4: DELIVERY VALIDATION
  // ═══════════════════════════════════════════════════════════

  logger.info(`[DELIVERY VALIDATION] Running complete validation for ${feature.id}`);

  const deliveryValidation = await this.runDeliveryValidation(sessionId, feature);

  if (!deliveryValidation.passed) {
    throw new Error(
      `DELIVERY VALIDATION FAILED: ${deliveryValidation.failures.join(', ')}`
    );
  }

  // Update feature status
  feature.status = 'completed';
  feature.passedTests = true;
  feature.evidenceLinks = deliveryValidation.evidenceUrls;
  feature.completedAt = new Date().toISOString();

  await this.updateFeatureStatus(sessionId, feature);

  logger.info(`  ✅ DELIVERY: All validations passed`);

  return {
    featureId: feature.id,
    status: 'completed',
    testFile,
    implementation,
    validation: deliveryValidation
  };
}

async runContinuousValidation(sessionId: string): Promise<void> {
  logger.info(`[CONTINUOUS VALIDATION] Running quality gates...`);

  // 1. TypeScript compilation
  const tsResult = await this.runCommand('npx tsc --noEmit --skipLibCheck');
  if (tsResult.exitCode !== 0) {
    throw new Error(`TypeScript compilation failed: ${tsResult.stderr}`);
  }
  logger.info(`  ✅ TypeScript compilation clean`);

  // 2. ESLint validation
  const eslintResult = await this.runCommand('npm run lint');
  if (eslintResult.exitCode !== 0) {
    throw new Error(`ESLint validation failed: ${eslintResult.stderr}`);
  }
  logger.info(`  ✅ ESLint validation passed`);

  // 3. Schema drift check
  const schemaResult = await this.runCommand('npm run validate:schema-drift');
  if (schemaResult.exitCode !== 0) {
    throw new Error(`Schema drift detected: ${schemaResult.stderr}`);
  }
  logger.info(`  ✅ No schema drift`);

  // 4. API contract compliance
  const contractResult = await this.runCommand('npm run api:test:contracts');
  if (contractResult.exitCode !== 0) {
    throw new Error(`API contract violations: ${contractResult.stderr}`);
  }
  logger.info(`  ✅ API contracts compliant`);

  // 5. Critical tests
  const testResult = await this.runCommand('npm run test:critical');
  if (testResult.exitCode !== 0) {
    throw new Error(`Critical tests failing: ${testResult.stderr}`);
  }
  logger.info(`  ✅ Critical tests passing`);
}
```

---

## 2. PM33 Workflow Implementations

### 2.1 Competitive Discovery (Long-Running Multi-Session Workflow)

**Use Case**: User triggers "Discover Competitors" → Agent runs 4-phase workflow across multiple sessions:
1. **Company Analysis** (extract YOUR differentiators from strategy sources)
2. **Competitor Identification** (AI finds competitors based on your differentiators)
3. **Competitor Analysis** (extract THEIR data via website crawling)
4. **Comparative SWOT** (YOU vs THEM analysis)

**Implementation Pattern**:

**Initializer Session**:
```typescript
// /server/services/competitive-discovery/CompetitiveDiscoveryOrchestrator.ts

export class CompetitiveDiscoveryOrchestrator {
  async initializeDiscoveryWorkflow(
    tenantId: string,
    workspaceId: string,
    userId: string,
    strategySourceId: string
  ): Promise<DiscoverySession> {

    // 1. Create progress tracking artifacts
    const session = await this.createDiscoverySession({
      tenantId,
      workspaceId,
      userId,
      strategySourceId,
      status: 'initializing'
    });

    // 2. Create feature checklist (pm33-agent-progress.json)
    const featureChecklist = this.createCompetitiveDiscoveryChecklist();
    await this.saveProgressArtifact(session.id, 'features.json', featureChecklist);

    // 3. Initialize session log (claude-progress.txt)
    const initialLog = `=== DISCOVERY SESSION INITIALIZED ${new Date().toISOString()} ===
Workflow: Competitive Discovery
Strategy Source: ${strategySourceId}
Total Features: ${featureChecklist.totalFeatures}
Status: Ready for Phase 1
`;
    await this.saveProgressArtifact(session.id, 'progress.txt', initialLog);

    // 4. Set up validation tests
    await this.createValidationTests(session.id);

    // 5. Create initial checkpoint
    await this.createCheckpoint(session.id, 'initialization', {
      message: 'Discovery workflow initialized',
      features: featureChecklist
    });

    // 6. Transition to Phase 1
    await this.updateSessionStatus(session.id, 'phase_1_company_analysis');

    return session;
  }
}
```

**Coding Session (Phase 1)**:
```typescript
export class CompetitiveDiscoveryOrchestrator {
  async executePhase1CompanyAnalysis(sessionId: string): Promise<Phase1Result> {

    // 1. Load state artifacts
    const session = await this.loadSession(sessionId);
    const progress = await this.loadProgressArtifact(sessionId, 'progress.txt');
    const features = await this.loadProgressArtifact(sessionId, 'features.json');

    logger.info('[Phase 1] Starting Company Analysis', {
      sessionId,
      lastCheckpoint: progress.split('\n')[0]
    });

    // 2. Validate environment
    const validation = await this.runValidationTests(sessionId, 'baseline');
    if (!validation.passed) {
      throw new Error(`Validation failed: ${validation.errors.join(', ')}`);
    }

    // 3. Execute SINGLE feature: Extract YOUR differentiators
    const featureId = 'CD-001';
    const feature = features.features.find(f => f.id === featureId);

    const differentiators = await this.extractCompanyDifferentiators(
      session.tenantId,
      session.workspaceId,
      session.strategySourceId
    );

    // 4. End-to-end validation
    const e2eResult = await this.runE2ETest(sessionId, 'phase-1-company-analysis');
    if (!e2eResult.passed) {
      throw new Error(`E2E test failed: ${e2eResult.error}`);
    }

    // 5. Create checkpoint (git commit equivalent)
    const checkpoint = await this.createCheckpoint(sessionId, 'phase_1_complete', {
      message: 'Phase 1: Company analysis complete',
      differentiators: differentiators.length,
      confidence: differentiators.reduce((acc, d) => acc + d.confidence, 0) / differentiators.length
    });

    // 6. Update progress artifacts
    feature.status = 'completed';
    feature.passedTests = true;
    feature.completedAt = new Date().toISOString();
    feature.checkpointId = checkpoint.id;

    await this.saveProgressArtifact(sessionId, 'features.json', features);

    const progressUpdate = `\n=== SESSION ${new Date().toISOString()} ===
Feature: ${feature.name}
Status: ✅ COMPLETED
Differentiators Extracted: ${differentiators.length}
Avg Confidence: ${Math.round((differentiators.reduce((acc, d) => acc + d.confidence, 0) / differentiators.length) * 100)}%
Validation: ✅ E2E test passed
Checkpoint: ${checkpoint.id}
Next Session: Phase 2 (Competitor Identification)
`;
    await this.appendProgressArtifact(sessionId, 'progress.txt', progressUpdate);

    // 7. Transition to next phase
    await this.updateSessionStatus(sessionId, 'phase_2_competitor_identification');

    return {
      phase: 1,
      status: 'completed',
      differentiators,
      nextPhase: 2,
      checkpointId: checkpoint.id
    };
  }
}
```

**Key Implementation Details**:
- **No multi-feature attempts**: Each phase = ONE feature completion + checkpoint
- **Git-like checkpoints**: Database table `discovery_checkpoints` stores recoverable state
- **WebSocket progress updates**: Real-time UI updates during long-running extraction
- **E2E validation**: Playwright tests validate complete workflow before checkpoint
- **Human-readable logs**: claude-progress.txt + JSON checklist = full context preservation

### 2.2 Strategy Analysis (Iterative Website Extraction)

**Use Case**: User adds website → Extract comprehensive data across multiple sessions:
1. **Session 1**: Homepage crawl + initial extraction (mission, vision, basic data)
2. **Session 2**: Deep crawl (/pricing, /about, /features) + enhanced extraction
3. **Session 3**: Consolidation + confidence scoring + merge to canonical strategy

**Implementation Pattern**: Same orchestrator structure, different phases:
- **Initializer**: Create extraction session, set up multi-page crawl queue
- **Coding Session 1**: Process homepage, extract basic fields, checkpoint
- **Coding Session 2**: Process deep pages, extract comprehensive fields, checkpoint
- **Coding Session 3**: Consolidate, score confidence, merge, final checkpoint

### 2.3 PRD Generation (Progressive Refinement)

**Use Case**: User generates PRD → Agent iteratively refines across sessions:
1. **Session 1**: Extract requirements from backlog + strategy context
2. **Session 2**: Generate initial PRD sections (Problem, Solution, Success Metrics)
3. **Session 3**: Refine with user feedback + add technical specs
4. **Session 4**: Final polish + export

**Implementation Pattern**: Session-based refinement with user feedback loops:
- **Initializer**: Create PRD draft session, load backlog + strategy context
- **Coding Session N**: Refine specific section based on user feedback, checkpoint
- **Final Session**: Export finalized PRD, close session

---

## 3. Database Schema

### 3.1 Discovery Sessions Table

```sql
-- /migrations/YYYYMMDD_add_discovery_sessions.sql

CREATE TABLE IF NOT EXISTS discovery_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id VARCHAR NOT NULL REFERENCES tenants(id),
  workspace_id UUID NOT NULL,
  user_id VARCHAR NOT NULL REFERENCES users(id),

  -- Session metadata
  session_type VARCHAR NOT NULL, -- 'competitive_discovery', 'strategy_analysis', 'prd_generation'
  status VARCHAR NOT NULL, -- 'initializing', 'phase_1_company_analysis', 'phase_2_competitor_id', etc.

  -- Context references
  strategy_source_id UUID REFERENCES strategy_sources(id),

  -- Progress tracking
  total_features INTEGER NOT NULL DEFAULT 0,
  completed_features INTEGER NOT NULL DEFAULT 0,
  current_feature_id VARCHAR,

  -- State artifacts (JSONB for flexibility)
  progress_log TEXT, -- claude-progress.txt equivalent
  feature_checklist JSONB, -- pm33-agent-progress.json
  validation_results JSONB,

  -- Timestamps
  started_at TIMESTAMP NOT NULL DEFAULT NOW(),
  last_activity_at TIMESTAMP NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMP,

  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_discovery_sessions_tenant_workspace ON discovery_sessions(tenant_id, workspace_id);
CREATE INDEX idx_discovery_sessions_status ON discovery_sessions(status);
CREATE INDEX idx_discovery_sessions_user ON discovery_sessions(user_id);
```

### 3.2 Discovery Checkpoints Table

```sql
-- Git-like checkpoint system for recovery

CREATE TABLE IF NOT EXISTS discovery_checkpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES discovery_sessions(id) ON DELETE CASCADE,

  -- Checkpoint metadata
  checkpoint_type VARCHAR NOT NULL, -- 'initialization', 'phase_complete', 'feature_complete', 'error_recovery'
  message TEXT NOT NULL,

  -- State snapshot
  session_state JSONB NOT NULL, -- Complete session state at this point
  feature_state JSONB NOT NULL, -- Feature checklist state
  validation_results JSONB,

  -- Recovery information
  is_rollback_point BOOLEAN DEFAULT true,
  parent_checkpoint_id UUID REFERENCES discovery_checkpoints(id),

  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_checkpoints_session ON discovery_checkpoints(session_id);
CREATE INDEX idx_checkpoints_type ON discovery_checkpoints(checkpoint_type);
CREATE INDEX idx_checkpoints_rollback ON discovery_checkpoints(session_id, is_rollback_point);
```

---

## 4. API Endpoints

### 4.1 Discovery Session Management

```typescript
// POST /api/discovery/sessions/start
// Initialize a new discovery session (Initializer Agent)
router.post('/sessions/start', tenantMiddleware, requireAuth, async (req, res) => {
  const { sessionType, strategySourceId } = req.body;

  const session = await orchestrator.initializeDiscoveryWorkflow(
    req.tenantId,
    req.user.workspaceId,
    req.user.id,
    strategySourceId
  );

  res.json(session);
});

// POST /api/discovery/sessions/:sessionId/execute-phase
// Execute next phase (Coding Agent)
router.post('/sessions/:sessionId/execute-phase', tenantMiddleware, requireAuth, async (req, res) => {
  const { sessionId } = req.params;

  const session = await orchestrator.loadSession(sessionId);

  let result;
  switch (session.status) {
    case 'phase_1_company_analysis':
      result = await orchestrator.executePhase1CompanyAnalysis(sessionId);
      break;
    case 'phase_2_competitor_identification':
      result = await orchestrator.executePhase2CompetitorID(sessionId);
      break;
    case 'phase_3_competitor_analysis':
      result = await orchestrator.executePhase3CompetitorAnalysis(sessionId);
      break;
    case 'phase_4_comparative_swot':
      result = await orchestrator.executePhase4ComparativeSWOT(sessionId);
      break;
    default:
      return res.status(400).json({ error: 'Invalid session status' });
  }

  res.json(result);
});

// GET /api/discovery/sessions/:sessionId/progress
// Get current progress state
router.get('/sessions/:sessionId/progress', tenantMiddleware, requireAuth, async (req, res) => {
  const { sessionId } = req.params;

  const session = await orchestrator.loadSession(sessionId);
  const features = await orchestrator.loadProgressArtifact(sessionId, 'features.json');
  const progress = await orchestrator.loadProgressArtifact(sessionId, 'progress.txt');

  res.json({
    session,
    features,
    progressLog: progress.split('\n===').slice(-3).join('\n===') // Last 3 sessions
  });
});

// POST /api/discovery/sessions/:sessionId/rollback
// Rollback to previous checkpoint
router.post('/sessions/:sessionId/rollback', tenantMiddleware, requireAuth, async (req, res) => {
  const { sessionId } = req.params;
  const { checkpointId } = req.body;

  const restoredSession = await orchestrator.rollbackToCheckpoint(sessionId, checkpointId);

  res.json(restoredSession);
});
```

### 4.2 WebSocket Progress Updates

```typescript
// /server/services/competitive-discovery/DiscoveryWebSocketService.ts

export class DiscoveryWebSocketService {
  private io: SocketIO;

  async broadcastProgress(sessionId: string, update: ProgressUpdate) {
    this.io.to(`discovery-${sessionId}`).emit('discovery:progress', {
      sessionId,
      phase: update.phase,
      status: update.status,
      progress: update.progress, // 0-100
      message: update.message,
      timestamp: new Date().toISOString()
    });
  }

  async broadcastPhaseComplete(sessionId: string, phase: number, result: any) {
    this.io.to(`discovery-${sessionId}`).emit('discovery:phase_complete', {
      sessionId,
      phase,
      result,
      nextPhase: phase + 1,
      timestamp: new Date().toISOString()
    });
  }

  async broadcastError(sessionId: string, error: Error) {
    this.io.to(`discovery-${sessionId}`).emit('discovery:error', {
      sessionId,
      error: error.message,
      recoverable: true, // Can rollback to last checkpoint
      timestamp: new Date().toISOString()
    });
  }
}
```

---

## 5. Frontend Components

### 5.1 Discovery Progress Monitor

```typescript
// /client/src/components/competitive-discovery/DiscoveryProgressMonitor.tsx

export const DiscoveryProgressMonitor: React.FC<{ sessionId: string }> = ({ sessionId }) => {
  const [progress, setProgress] = useState<DiscoveryProgress | null>(null);
  const socket = useSocket();

  useEffect(() => {
    // Subscribe to WebSocket updates
    socket.on(`discovery:progress`, (update) => {
      if (update.sessionId === sessionId) {
        setProgress(prev => ({
          ...prev,
          phase: update.phase,
          status: update.status,
          progress: update.progress,
          message: update.message
        }));
      }
    });

    socket.on(`discovery:phase_complete`, (update) => {
      if (update.sessionId === sessionId) {
        setProgress(prev => ({
          ...prev,
          phase: update.nextPhase,
          status: 'ready',
          phaseResults: [...(prev?.phaseResults || []), update.result]
        }));
      }
    });

    return () => {
      socket.off(`discovery:progress`);
      socket.off(`discovery:phase_complete`);
    };
  }, [sessionId, socket]);

  return (
    <div className="discovery-progress">
      <ProgressStepper
        currentPhase={progress?.phase || 1}
        phases={['Company Analysis', 'Competitor ID', 'Competitor Analysis', 'Comparative SWOT']}
      />

      <ProgressBar value={progress?.progress || 0} />

      <p className="status-message">{progress?.message || 'Initializing...'}</p>

      {progress?.phaseResults && (
        <PhaseResultsSummary results={progress.phaseResults} />
      )}
    </div>
  );
};
```

---

## 6. Validation Testing Framework

### 6.1 E2E Test Structure

```typescript
// /tests/e2e/competitive-discovery/phase-1-company-analysis.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Competitive Discovery - Phase 1: Company Analysis', () => {

  test('should extract company differentiators from strategy sources', async ({ page }) => {
    // 1. Navigate to strategy sources
    await page.goto('http://localhost:5001/strategy');

    // 2. Upload website source (if not exists)
    const hasSource = await page.locator('[data-testid="website-card"]').count() > 0;
    if (!hasSource) {
      await page.click('[data-testid="add-website-source"]');
      await page.fill('[data-testid="website-url-input"]', 'https://b33.tech');
      await page.click('[data-testid="analyze-website-button"]');
      await page.waitForSelector('[data-testid="website-card"]', { timeout: 60000 });
    }

    // 3. Start competitive discovery
    await page.click('[data-testid="start-discovery-button"]');

    // 4. Wait for Phase 1 completion
    await page.waitForSelector('[data-testid="phase-1-complete"]', { timeout: 120000 });

    // 5. Validate differentiators extracted
    const differentiators = await page.locator('[data-testid="differentiator-item"]').count();
    expect(differentiators).toBeGreaterThan(0);

    // 6. Validate confidence scores visible
    const firstDifferentiator = page.locator('[data-testid="differentiator-item"]').first();
    const confidence = await firstDifferentiator.locator('[data-testid="confidence-score"]').textContent();
    expect(confidence).toMatch(/\d+%/);

    // 7. Validate "Continue to Phase 2" button enabled
    const phase2Button = page.locator('[data-testid="continue-phase-2-button"]');
    await expect(phase2Button).toBeEnabled();
  });

  test('should allow editing differentiators before discovery', async ({ page }) => {
    // ... test implementation
  });

  test('should rollback to checkpoint on error', async ({ page }) => {
    // ... test implementation
  });
});
```

---

## 7. Quality Enforcement Mechanisms

### 7.1 Continuous Quality Gates (MANDATORY)

**Enforced At**: Every code change, every checkpoint, every session start

```typescript
// /server/services/quality-gates/QualityGateOrchestrator.ts

export class QualityGateOrchestrator {
  private readonly gates: QualityGate[] = [
    new SchemaValidationGate(),
    new TypeScriptCompilationGate(),
    new ESLintValidationGate(),
    new ContractComplianceGate(),
    new TestExecutionGate()
  ];

  async runAllGates(context: QualityContext): Promise<QualityResult> {
    const results: GateResult[] = [];

    for (const gate of this.gates) {
      logger.info(`Running ${gate.name}...`);

      const result = await gate.execute(context);

      results.push(result);

      if (!result.passed && result.blocking) {
        // BLOCKING FAILURE - Halt execution
        throw new QualityGateException(
          `BLOCKED BY ${gate.name}: ${result.error}`,
          gate.name,
          result.remediation
        );
      }

      if (!result.passed && !result.blocking) {
        // NON-BLOCKING WARNING
        logger.warn(`⚠️  ${gate.name}: ${result.warning}`);
      }
    }

    return {
      passed: results.every(r => r.passed),
      gates: results,
      timestamp: new Date().toISOString()
    };
  }
}

// Individual Gate Implementations

class SchemaValidationGate implements QualityGate {
  name = 'Schema Drift Validation';
  blocking = true;

  async execute(context: QualityContext): Promise<GateResult> {
    const result = await runCommand('npm run validate:schema-drift');

    if (result.exitCode !== 0) {
      return {
        passed: false,
        blocking: true,
        error: 'Schema drift detected - shared/schema.ts out of sync with database',
        remediation: [
          '1. Run: npm run validate:schema-drift',
          '2. Review generated migration SQL',
          '3. Create migration file in server/migrations/',
          '4. Run: npm run db:migrate:dev',
          '5. Verify: npm run validate:schema-drift shows ✅'
        ]
      };
    }

    return { passed: true, blocking: false };
  }
}

class TypeScriptCompilationGate implements QualityGate {
  name = 'TypeScript Compilation';
  blocking = true;

  async execute(context: QualityContext): Promise<GateResult> {
    const result = await runCommand('npx tsc --noEmit --skipLibCheck');

    if (result.exitCode !== 0) {
      return {
        passed: false,
        blocking: true,
        error: 'TypeScript compilation errors detected',
        remediation: [
          '1. Run: npx tsc --noEmit',
          '2. Fix all type errors',
          '3. Re-run quality gates'
        ],
        details: result.stderr
      };
    }

    return { passed: true, blocking: false };
  }
}

class ESLintValidationGate implements QualityGate {
  name = 'ESLint Validation';
  blocking = true;

  async execute(context: QualityContext): Promise<GateResult> {
    const result = await runCommand('npm run lint');

    if (result.exitCode !== 0) {
      return {
        passed: false,
        blocking: true,
        error: 'ESLint errors detected',
        remediation: [
          '1. Run: npm run lint',
          '2. Run: npm run lint:fix (for auto-fixable issues)',
          '3. Manually fix remaining errors',
          '4. Re-run quality gates'
        ],
        details: result.stdout
      };
    }

    return { passed: true, blocking: false };
  }
}

class ContractComplianceGate implements QualityGate {
  name = 'API Contract Compliance';
  blocking = true;

  async execute(context: QualityContext): Promise<GateResult> {
    const result = await runCommand('npm run api:test:contracts');

    if (result.exitCode !== 0) {
      return {
        passed: false,
        blocking: true,
        error: 'API contract violations detected',
        remediation: [
          '1. Run: npm run api:test:contracts',
          '2. Review failing contracts',
          '3. Update Zod schemas in /server/contracts/',
          '4. Mirror types in /client/src/types/',
          '5. Re-run quality gates'
        ],
        details: result.stdout
      };
    }

    return { passed: true, blocking: false };
  }
}

class TestExecutionGate implements QualityGate {
  name = 'Critical Test Execution';
  blocking = true;

  async execute(context: QualityContext): Promise<GateResult> {
    const result = await runCommand('npm run test:critical');

    if (result.exitCode !== 0) {
      return {
        passed: false,
        blocking: true,
        error: 'Critical tests failing',
        remediation: [
          '1. Run: npm run test:critical',
          '2. Identify failing tests',
          '3. Fix broken functionality',
          '4. Ensure tests pass',
          '5. Re-run quality gates'
        ],
        details: result.stdout
      };
    }

    return { passed: true, blocking: false };
  }
}
```

### 7.2 Context Reading Validation

**Enforced At**: Before ANY feature implementation

```typescript
// /server/services/context-validation/ContextValidator.ts

export class ContextValidator {
  private requiredDocumentTypes = [
    'prd_section',
    'wireframe',
    'api_contract',
    'database_schema'
  ];

  async validateContextReading(
    sessionId: string,
    featureId: string
  ): Promise<ContextValidationResult> {

    const feature = await this.loadFeature(sessionId, featureId);

    const contextLog: ContextLog = {
      featureId,
      contextFilesRead: [],
      documentTypesRead: new Set(),
      readTimestamps: {},
      validationPassed: false,
      missingContext: []
    };

    // 1. PRD Sections (REQUIRED)
    if (feature.requiredPRDSections && feature.requiredPRDSections.length > 0) {
      for (const prd of feature.requiredPRDSections) {
        await this.readAndLogFile(prd, 'prd_section', contextLog);
      }
    } else {
      contextLog.missingContext.push('PRD sections not specified for feature');
    }

    // 2. Wireframes (REQUIRED for UI features)
    if (feature.isUIFeature) {
      if (feature.wireframeReferences && feature.wireframeReferences.length > 0) {
        for (const wireframe of feature.wireframeReferences) {
          await this.readAndLogFile(wireframe.file, 'wireframe', contextLog);
        }
      } else {
        contextLog.missingContext.push('Wireframe references missing for UI feature');
      }
    }

    // 3. API Contracts (REQUIRED for backend features)
    if (feature.isBackendFeature) {
      if (feature.apiContracts && feature.apiContracts.length > 0) {
        for (const contract of feature.apiContracts) {
          await this.readAndLogFile(`/server/contracts/${contract}`, 'api_contract', contextLog);
        }
      } else {
        contextLog.missingContext.push('API contracts missing for backend feature');
      }
    }

    // 4. Database Schema (ALWAYS REQUIRED)
    await this.readAndLogFile('/shared/schema.ts', 'database_schema', contextLog);

    // 5. Recent Migrations (ALWAYS REQUIRED)
    const migrations = await this.getRecentMigrations(30);
    for (const migration of migrations) {
      await this.readAndLogFile(migration.file, 'database_schema', contextLog);
    }

    // VALIDATION: Check all required document types were read
    const missingTypes = this.requiredDocumentTypes.filter(
      type => !contextLog.documentTypesRead.has(type)
    );

    if (missingTypes.length > 0 || contextLog.missingContext.length > 0) {
      throw new ContextValidationException(
        `CONTEXT VALIDATION FAILED for feature ${featureId}`,
        {
          missingDocumentTypes: missingTypes,
          missingContext: contextLog.missingContext,
          filesRead: contextLog.contextFilesRead.length
        }
      );
    }

    contextLog.validationPassed = true;

    // Log to progress.txt
    await this.logContextReading(sessionId, contextLog);

    return {
      passed: true,
      contextLog
    };
  }

  private async readAndLogFile(
    filePath: string,
    documentType: string,
    contextLog: ContextLog
  ): Promise<void> {
    const content = await fs.readFile(filePath, 'utf-8');

    contextLog.contextFilesRead.push(filePath);
    contextLog.documentTypesRead.add(documentType);
    contextLog.readTimestamps[filePath] = new Date().toISOString();

    logger.info(`  ✅ Read [${documentType}]: ${filePath} (${content.length} chars)`);
  }
}
```

### 7.3 Pre-Checkpoint Quality Validation

**Enforced At**: Before creating ANY checkpoint (red, green, refactor, feature complete)

```typescript
async createCheckpoint(
  sessionId: string,
  checkpointType: string,
  metadata: any
): Promise<Checkpoint> {

  logger.info(`[CHECKPOINT] Creating ${checkpointType} for session ${sessionId}`);

  // MANDATORY: Run all quality gates before checkpoint
  logger.info(`[QUALITY GATES] Running pre-checkpoint validation...`);

  const qualityResult = await this.qualityGateOrchestrator.runAllGates({
    sessionId,
    checkpointType
  });

  if (!qualityResult.passed) {
    throw new Error(
      `CHECKPOINT BLOCKED: Quality gates failed. Cannot create checkpoint until all gates pass.`
    );
  }

  logger.info(`  ✅ All quality gates passed`);

  // NOW create checkpoint
  const checkpoint = await db.insert(discoveryCheckpoints).values({
    sessionId,
    checkpointType,
    message: metadata.message || `${checkpointType} checkpoint`,
    sessionState: await this.getSessionState(sessionId),
    featureState: await this.getFeatureState(sessionId),
    validationResults: qualityResult,
    isRollbackPoint: true
  });

  logger.info(`  ✅ Checkpoint created: ${checkpoint.id}`);

  return checkpoint;
}
```

---

## 8. Implementation Checklist (TDD + Quality Gates Enhanced)

### Phase 1: Foundation (10-14 hours)
- [ ] **Database Schema**
  - [ ] Create database migrations (discovery_sessions, discovery_checkpoints)
  - [ ] Run schema drift validation before/after migration
  - [ ] Write migration E2E tests
- [ ] **Quality Gate Infrastructure**
  - [ ] Implement QualityGateOrchestrator service
  - [ ] Create individual gate implementations (5 gates)
  - [ ] Write quality gate unit tests (>95% coverage)
  - [ ] Integrate with init.sh script
- [ ] **Context Validation Infrastructure**
  - [ ] Implement ContextValidator service
  - [ ] Create context reading enforcement logic
  - [ ] Write context validation tests
- [ ] **Progress Artifacts**
  - [ ] Create progress artifact file structure (/docs/frameworks/agent-state/)
  - [ ] Implement checkpoint create/rollback logic with quality gate enforcement
  - [ ] Write checkpoint rollback E2E tests
- [ ] **Environment Setup**
  - [ ] Add init.sh script with 6 quality gates
  - [ ] Write baseline E2E validation tests
  - [ ] Test complete init.sh workflow

### Phase 2: TDD Workflow Integration (12-16 hours)
- [ ] **Red-Green-Refactor Implementation**
  - [ ] Implement RED phase (failing test generation)
  - [ ] Implement GREEN phase (minimal implementation + continuous validation)
  - [ ] Implement REFACTOR phase (iterative cleanup with gate checks)
  - [ ] Write TDD workflow E2E tests
- [ ] **Continuous Validation**
  - [ ] Integrate quality gates after every code change
  - [ ] Implement automatic rollback on gate failures
  - [ ] Write continuous validation tests
- [ ] **Delivery Validation**
  - [ ] Integrate delivery validation framework
  - [ ] Evidence collection automation (coverage, performance, a11y, visual)
  - [ ] Write delivery validation E2E tests

### Phase 3: Competitive Discovery Integration (16-20 hours)
- [ ] **Context Reading Enforcement**
  - [ ] Phase 1: Company Analysis - Context validation BEFORE implementation
  - [ ] Phase 2: Competitor Identification - Context validation BEFORE implementation
  - [ ] Phase 3: Competitor Analysis - Context validation BEFORE implementation
  - [ ] Phase 4: Comparative SWOT - Context validation BEFORE implementation
- [ ] **TDD Implementation**
  - [ ] Write failing E2E tests for all 4 phases (RED)
  - [ ] Implement minimal code to pass tests (GREEN) with continuous gates
  - [ ] Refactor with quality gate checks (REFACTOR)
  - [ ] Collect delivery evidence for all phases
- [ ] **API Endpoints**
  - [ ] Create Zod contracts BEFORE implementation
  - [ ] Implement /sessions/start with contract validation
  - [ ] Implement /execute-phase with context + quality gates
  - [ ] Implement /progress and /rollback endpoints
  - [ ] Write API contract compliance tests
- [ ] **WebSocket Integration**
  - [ ] Implement WebSocket progress broadcasting
  - [ ] Write WebSocket E2E tests
- [ ] **Frontend Components**
  - [ ] Build DiscoveryProgressMonitor with wireframe compliance
  - [ ] Write component visual regression tests
  - [ ] Accessibility audit (WCAG 2.1 AA)

### Phase 4: Other Workflows (10-14 hours)
- [ ] **Strategy Analysis Workflow**
  - [ ] Adapt orchestrator with TDD workflow
  - [ ] Create workflow-specific feature checklist
  - [ ] Write context validation rules
  - [ ] Write E2E tests with quality gates
- [ ] **PRD Generation Workflow**
  - [ ] Adapt orchestrator with TDD workflow
  - [ ] Create workflow-specific feature checklist
  - [ ] Write context validation rules
  - [ ] Write E2E tests with quality gates

### Phase 5: Validation & Documentation (8-10 hours)
- [ ] **Complete Test Suite**
  - [ ] Run all E2E tests (competitive discovery, strategy, PRD)
  - [ ] Achieve >95% test coverage on new code
  - [ ] Run performance testing (multi-session workflows)
  - [ ] Run accessibility audit across all components
- [ ] **Quality Gate Validation**
  - [ ] Verify all 6 quality gates working correctly
  - [ ] Test checkpoint rollback scenarios
  - [ ] Test context validation enforcement
  - [ ] Test TDD workflow enforcement
- [ ] **Documentation**
  - [ ] Create user documentation (how to use discovery workflows)
  - [ ] Create developer documentation (how to add new workflows)
  - [ ] Update API governance framework
  - [ ] Update delivery validation framework
  - [ ] Create training materials for QA team

**Total Estimate**: 56-74 hours (11-15 weeks with testing + review + QA)

**Quality Metrics**:
- **Test Coverage**: >95% on all new code
- **Schema Drift**: 0 drift incidents
- **ESLint Errors**: 0 errors at all checkpoints
- **Contract Violations**: 0 violations at all checkpoints
- **Context Validation**: 100% compliance (all features read required context)
- **TDD Compliance**: 100% (all features follow Red-Green-Refactor)
- **Delivery Evidence**: 100% (all features have coverage/performance/a11y/visual reports)

---

## 8. Success Metrics

### Technical Metrics
- **Session Completion Rate**: 95%+ of discovery sessions complete all phases
- **Checkpoint Rollback Rate**: <5% (indicates stable execution)
- **E2E Test Pass Rate**: 98%+ across all workflows
- **Average Session Duration**: <10 minutes per phase (4 phases = <40 min total)

### User Metrics
- **Discovery Adoption**: 60%+ of users who add website sources trigger discovery
- **Competitor Approval Rate**: 80%+ of AI-discovered competitors approved by users
- **PRD Refinement Iterations**: Avg 2-3 sessions to finalized PRD
- **Strategy Analysis Accuracy**: 90%+ confidence on extracted data fields

### Business Metrics
- **Premium Conversion**: 8% of free users upgrade for unlimited discovery
- **Time Saved**: 4 hours/week per PM (vs manual competitor research)
- **Competitive Intelligence Quality**: 85%+ SWOT accuracy validated by users

---

## 9. Anti-Patterns to Avoid

### ❌ DON'T: Attempt Multi-Feature Implementation Per Session
**Why**: Exhausts context window, leads to incomplete/buggy features
**Instead**: Single feature per session, checkpoint after completion

### ❌ DON'T: Skip E2E Testing in Favor of Unit Tests
**Why**: Unit tests don't validate complete user workflows
**Instead**: Browser automation (Playwright) validates end-to-end functionality

### ❌ DON'T: Store State Only in Memory
**Why**: Context resets between sessions lose progress
**Instead**: Persist state in database + human-readable files (JSON, TXT)

### ❌ DON'T: Use Markdown for Structured Data
**Why**: LLMs preserve JSON better than Markdown tables/lists
**Instead**: Use JSONB for feature checklists, validation results, metadata

### ❌ DON'T: Auto-Approve Low-Confidence Results
**Why**: Reduces user trust, leads to bad competitive intelligence
**Instead**: Show confidence scores, enable "Quick Approve" for high-confidence batches

### ❌ DON'T: Ignore Environment Validation
**Why**: Undetected regressions break subsequent sessions
**Instead**: Run init.sh + baseline tests at start of every session

---

## 10. Next Steps

1. **Review with Backend Architect**: Validate orchestrator architecture + database schema
2. **Create Jira Tickets**: Break down implementation checklist into sprint-sized tasks
3. **Prioritize Workflows**: Start with Competitive Discovery (highest user value)
4. **Parallel Development**: Frontend components + Backend services can proceed in parallel
5. **Sprint Planning**: Allocate 8-10 weeks for complete implementation + testing

---

## References

- **Anthropic Blog**: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- **PM33 Competitive Discovery Plan**: `/docs/plans/COMPETITIVE_DISCOVERY_INTEGRATION_PLAN_REVIEWED.md`
- **PM33 Delivery Validation Framework**: `/docs/frameworks/DELIVERY_VALIDATION_FRAMEWORK.md`
- **PM33 API Governance Framework**: `/API_GOVERNANCE_FRAMEWORK.md`
- **PM33 Schema Change Workflow**: `/docs/SCHEMA_CHANGE_WORKFLOW.md`
