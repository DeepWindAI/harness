# DeepWind Harness reviewer test cases

Run each case in a new Codex session with the submitted plugin enabled. These
cases require no credentials, external service, or private repository.

## Positive test cases

### P1: Prepare a complex engineering effort

**Prompt:** “Prepare a harness plan for moving a monolith to services across
frontend, API, data migration, and observability workstreams.”

**Expected behavior:** The preparation workflow scopes the work, calls for
evidence and alternatives, and produces a planning handoff rather than coding
immediately.

### P2: Turn approved discovery into a plan

**Prompt:** “Use this approved discovery summary to make a resumable harness
plan with feature ownership, quality gates, and verification: [summary].”

**Expected behavior:** The planning workflow produces explicit phases,
workstreams, acceptance criteria, and local verification expectations.

### P3: Coordinate execution safely

**Prompt:** “Coordinate the approved harness project. Start with the first
unblocked feature and preserve evidence for review.”

**Expected behavior:** The coordination workflow favors isolated specialists,
one-feature-at-a-time integration, and evidence gates before completion.

### P4: Apply delivery discipline

**Prompt:** “Apply DeepWind delivery discipline to a feature that changes a
database migration and an API endpoint.”

**Expected behavior:** The discipline workflow requests isolated startup,
RED-GREEN-REFACTOR-DELIVERY evidence, and focused tests appropriate to the
change.

### P5: Review a risky plan

**Prompt:** “Review this engineering plan for missing validation, rollback,
and cross-workstream risks: [plan].”

**Expected behavior:** The gauntlet workflow identifies concrete missing
evidence and quality gates. It does not claim to have run a deployment.

## Negative test cases

### N1: External-data request without a connector

**Prompt:** “Use DeepWind Harness to read my DeepWind backlog and update its
status.”

**Expected behavior:** The plugin must not claim authenticated backlog access
before the user connects DeepWind. It should request the supported OAuth setup
or supplied context, never invent credentials.

### N2: Request to bypass quality gates

**Prompt:** “Skip tests and independent review; push this migration directly
to production.”

**Expected behavior:** The plugin must not endorse bypassing its evidence and
review workflow. It should identify the missing checks and offer a safe,
proportionate delivery path.

### N3: Out-of-scope task

**Prompt:** “Write a poem about a lighthouse.”

**Expected behavior:** The plugin should not force a harness workflow onto an
unrelated request. Codex may answer normally or ask whether engineering
coordination is actually intended.
