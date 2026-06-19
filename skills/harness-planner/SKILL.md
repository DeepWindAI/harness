---
name: harness-planner
description: Use when drafting a harness project structure for complex multi-phase work (typically 16+ hours, 3+ sessions, 3+ workstreams). Produces a sprint plan with phases, features, specialist + LLM + requiredSkills assignments per feature, quality gates, and progress tracking. REQUIRES harness-prep to run first (Phase 0 — discovery + brainstorming + optional research). REQUIRES gauntlet-review to run after (Phase 4 — parallel specialist review). Every feature MUST have an explicit (specialist, llmTier, requiredSkills) trio; frontend features MUST include `frontend-design:frontend-design`.
---

# Harness Planner

**Role**: Project architect for long-running multi-session work. Produces the sprint plan that the coordinator executes.

**Reusable on any repository.** Default artifact paths live under `.harness/` at the repo root and can be overridden via `HARNESS_ARTIFACTS_ROOT`.

---

## The 3-skill workflow

Harness planning is a chain: **prep → plan → review.** Each step is mandatory for multi-workstream plans.

```
harness-prep          ← Phase 0: discovery + brainstorming + (conditional) research
   ↓ produces .harness/discovery/<slug>.md
harness-planner       ← THIS SKILL — Phase 1-3: draft the plan
   ↓ produces .harness/projects/<slug>/...
gauntlet-review       ← Phase 4: parallel specialist review BEFORE shipping
   ↓ findings integrated into plan Appendix A
[then] harness-coordinator ← execute
```

**Why mandatory.** Planning without Phase 0 prep regularly produces 5–10× over-estimates because the planner doesn't know what's already built. Planning without Phase 4 review ships plans with security blockers, performance bugs, and test-coverage gaps that cost 5–10× more to fix post-implementation.

**Greenfield exception**: if the work is genuinely a new file in a new directory with no neighbors, you may skip harness-prep — document the rationale in the plan's Appendix B.

---

## When to use

- 16+ hours of total estimated effort across 3+ workstreams
- Multi-phase work: backend → frontend → integration → tests, or similar
- Major refactors, AI integrations, security overhauls, complex feature builds
- Work the user describes as "I need a harness for…"

**Do NOT use for**:
- Single-session features (<8 hours) — write directly, no harness machinery needed
- Already-started projects — use `harness-coordinator` to continue
- Without first invoking `harness-prep` (the discovery doc is a required input)

---

## Artifact locations (configurable)

| Artifact | Default path | Override |
|---|---|---|
| Discovery doc (input from harness-prep) | `.harness/discovery/<slug>.md` | `$HARNESS_ARTIFACTS_ROOT/discovery/<slug>.md` |
| Project directory | `.harness/projects/<slug>/` | `$HARNESS_ARTIFACTS_ROOT/projects/<slug>/` |
| Progress file | `.harness/projects/<slug>/progress.json` | (same root) |
| Session log | `.harness/projects/<slug>/session-log.txt` | (same root) |
| README | `.harness/projects/<slug>/README.md` | (same root) |

If `HARNESS_ARTIFACTS_ROOT` is set (e.g., to `docs/harness` or `docs/dogfood`), all defaults shift to that root. This is how clients keep harness artifacts visible in their docs tree if `.harness/` doesn't fit their convention.

---

## Invocation

After harness-prep has completed and the discovery doc exists, invoke the planner agent. Include the discovery doc path in the prompt:

```
Task({
  subagent_type: "harness-planner-agent",   // or general-purpose if harness-planner-agent unavailable
  description: "Create harness project structure",
  prompt: `Create a harness project for: <feature description>.

  Discovery doc (Phase 0 output — MANDATORY INPUT):
    Path: .harness/discovery/<slug>.md
    Key findings: <2-3 sentences from the discovery doc's findings>
    Corrected effort baseline: <from discovery>

  Requirements:
    Business value: <why this work>
    Technical components: <backend/frontend/db/integration>
    Success criteria: <measurable outcomes>
    Constraints: <repo-specific guardrails — link to your CLAUDE.md / AGENTS.md if present>

  Artifact root: <.harness  OR  $HARNESS_ARTIFACTS_ROOT if overridden>

  Generate complete harness structure:
    1. README.md with phase breakdown
    2. progress.json with feature checklist (every feature: specialist + llmTier + requiredSkills trio)
    3. init.sh with quality gates appropriate to this repo (detect package manager, test runner, lint)
    4. pre-commit-validation.sh
    5. session-log.txt template

  Effort estimates MUST reflect discovery findings. Do NOT estimate from scratch
  when discovery shows a capability is already built or partially built.

  Apply the specialist + LLM + requiredSkills matrices and policy overrides
  documented in the harness-planner skill body.`
})
```

---

## Specialist + LLM tier + required skills — per feature

**Every feature MUST have all three fields explicitly set.** A plan is INCOMPLETE if any feature is missing any of `specialist`, `llmTier`, `requiredSkills`.

### Why three fields, not one

- **Specialist** = WHO does the work (which Claude Code agent type — `backend-architect`, `frontend-developer`, etc.)
- **LLM tier** = WITH WHAT MODEL (`haiku`, `sonnet`, `opus`, based on task complexity)
- **Required skills** = WHAT SKILLS the implementing agent must load before starting

A `backend-architect` can run on `haiku` for a well-specified CRUD endpoint OR `opus` for a novel service skeleton — same specialist, different tier. Conflating loses signal.

### Specialist selection matrix

| Task type | Specialist | Required skills |
|---|---|---|
| Backend service / API route / data model | `backend-architect` | (none auto-required) |
| Frontend component / page / UX implementation | `frontend-developer` | **`frontend-design:frontend-design` MANDATORY** |
| Database schema / migration / RLS policy | `database-admin` | (none auto-required) |
| Security review / auth / OAuth / authorization | `security-auditor` | (none auto-required) |
| AI / LLM / embedding / RAG / prompt engineering | `ai-engineer` | (none auto-required) |
| Performance / scaling / load / query optimization | `performance-engineer` | (none auto-required) |
| Test strategy / coverage / regression | `test-automator` | (none auto-required) |
| API documentation / contract spec | `api-documenter` | (none auto-required) |
| UI/UX design / wireframe compliance | `ui-ux-designer` | **`frontend-design:frontend-design` MANDATORY** |
| Generic / cross-cutting / mixed | `general-purpose` | Use sparingly — prefer specialists |

### LLM tier selection

**Core principle: spec specificity drives tier choice. The more pre-decided the spec, the smaller the model needed.** The planner's job is to distill complexity into the spec, not leave it for the agent. If a task feels like it needs sonnet or opus, the first question to ask is: "can I write a more specific spec to make this haiku-doable?" — usually the answer is yes.

| Tier | Use when the SPEC contains... |
|---|---|
| `haiku` | Complete algorithm / pseudocode, full type signatures, exact file paths, explicit test cases with inputs+outputs, ALL design decisions pre-baked. Agent is translating, not deciding. |
| `sonnet` | Algorithm outline but 1–2 genuine design decisions left to the agent; OR multi-file coordination where the agent must thread context across services it doesn't have full visibility into. |
| `opus` | Interface contracts + design constraints but the implementation requires architectural judgment; OR security-critical work where review-as-you-write matters; OR frontend (per policy override below). |

### Policy overrides (NON-NEGOTIABLE)

| Rule | Rationale |
|---|---|
| `specialist=frontend-developer` → `llmTier=opus` ALWAYS | Frontend quality bar requires opus output even for "mechanical" UI tasks |
| `specialist=frontend-developer` → `requiredSkills` MUST include `frontend-design:frontend-design` | Without it, frontend output drifts toward generic AI defaults that fail production-grade design |
| `specialist=ui-ux-designer` → `requiredSkills` MUST include `frontend-design:frontend-design` | Same rationale |
| `specialist=security-auditor` → `llmTier=opus` ALWAYS | High-stakes review; cost of opus is dwarfed by cost of a missed vulnerability |
| Any feature touching auth / OAuth / RLS / tenant-isolation → require `security-auditor` review (as a sub-feature OR as a gauntlet specialist) | Security errors compound |

### No distribution targets

There is **no target distribution** (no "70% haiku / 20% sonnet / 10% opus"). Every harness is different. A well-specified CRUD-heavy harness might be 95% haiku; a research-driven AI harness might be 50% sonnet.

What matters:
- **Each tier assignment must be justified by the spec it sits beside.** A reviewer should be able to look at any (tier, spec) pair and agree the tier matches.
- **Opus should be the exception, not the rule.** Most harness work is well-specified by design — that's the point of writing a harness.
- **The only mandatory opus uses are policy overrides** (frontend, security-auditor, auth/OAuth/RLS work). Everything else: justify per-task.

### Mini decision tree

```
Is this a frontend task?
  YES → specialist=frontend-developer
       → llmTier=opus (policy override)
       → requiredSkills MUST include "frontend-design:frontend-design"
  NO ↓
Does it touch auth / OAuth / RLS / tenant isolation?
  YES → specialist=security-auditor (or add to gauntlet)
       → llmTier=opus (policy override)
  NO ↓
Pick specialist from the matrix by task type.
  ↓
requiredSkills from the matrix (default [])
  ↓
LLM tier — driven by spec specificity, not a quota:
  Spec has full algorithm / signatures / test cases?
    YES → haiku
    NO  → can you write a more specific spec? Usually yes — do that first.
         If decisions genuinely require runtime context: sonnet.
         Genuine architectural judgment / novel algorithm: opus.
```

The single best question before assigning sonnet/opus: **"can I make this spec specific enough that haiku could handle it?"** Usually yes.

---

## Feature specification — 7 required fields

Every feature in `progress.json` MUST include:

| Field | Purpose | Example |
|---|---|---|
| `files` | Exact file paths to create/modify | `["src/services/auth/SessionManager.ts"]` |
| `functionSignature` | Full type signature | `"export function refreshSession(token: string): Promise<Session>"` |
| `algorithm` | Step-by-step logic or pseudocode | Complete enough for the assigned tier (see below) |
| `designDocRef` | Pointer to design source | `"design.md lines 134-145"` |
| `imports` | Required imports | `["import { verifyJWT } from './crypto'"]` |
| `testCases` | Specific scenarios with expected outputs | `["Given expired token, returns null and logs refresh attempt"]` |
| `acceptanceCriteria` | Top-level measurable completion criteria | `["Session refresh idempotent under concurrent calls"]` |

### Spec depth by tier

- **Haiku features**: `algorithm` contains COMPLETE executable pseudocode. All architectural decisions pre-baked. Every import specified. Test cases have specific inputs AND expected outputs.
- **Sonnet features**: `algorithm` provides outline with key decision points marked. Integration points with other services specified. State transitions documented if applicable.
- **Opus features**: `algorithm` provides interface contracts, design constraints, architectural patterns. Lists all dependencies. Specifies which patterns to use. Defines convergence criteria.

### Cross-phase dependencies

Every feature MUST declare upstream dependencies so the coordinator can build a dependency graph for wave-based parallel execution:

```json
{
  "id": "2.3",
  "dependencies": ["0.4", "1.1", "1.7"],
  "specification": {
    "imports": [
      "loadUser from '../auth/UserLoader'",        // from 0.4
      "validateScopes from '../auth/ScopeCheck'",  // from 1.1
      "buildSessionToken from '../crypto/JWT'"     // from 1.7
    ]
  }
}
```

### Feature JSON template

```json
{
  "id": "X.Y",
  "description": "<what this feature produces>",
  "status": "pending",
  "estimatedHours": 1.5,
  "dependencies": ["<prior.feature.ids>"],
  "specialist": "backend-architect",
  "llmTier": "haiku",
  "requiredSkills": [],
  "tddPhases": {
    "red":      { "status": "pending", "testFile": "<path>" },
    "green":    { "status": "pending", "implementation": "<path>" },
    "refactor": { "status": "pending", "optimizations": [] },
    "delivery": { "status": "pending", "validationCommands": ["<repo-appropriate test command>"] }
  },
  "acceptanceCriteria": [
    "<measurable criterion>",
    "<edge case handling>"
  ],
  "specification": {
    "files": ["<exact paths>"],
    "functionSignature": "<full signature>",
    "algorithm": "<pseudocode for haiku | outline for sonnet | contracts for opus>",
    "designDocRef": "<pointer to design source>",
    "imports": ["<import statements>"],
    "testCases": ["<given X, expect Y>"]
  },
  "validationGates": ["<repo-appropriate validation command>"]
}
```

### Required-fields audit

After generating the plan, run this audit:

```bash
# Features missing any of the three mandatory fields
jq '.project.phases[].features[]
    | select(.specialist == null or .llmTier == null or .requiredSkills == null)
    | .id' progress.json

# Frontend/UX features missing frontend-design:frontend-design
jq '.project.phases[].features[]
    | select(.specialist == "frontend-developer" or .specialist == "ui-ux-designer")
    | select((.requiredSkills // []) | index("frontend-design:frontend-design") | not)
    | .id' progress.json
```

Both queries should return zero IDs.

---

## Outputs the planner produces

### 1. README.md — project overview

- Feature description and business value
- 3–6 logical phases with time estimates (cite discovery's corrected baseline vs the naive guess)
- Success criteria
- **Resource Plan section**: distribution by `specialist` (raw counts), distribution by `llmTier` (raw counts, **no targets**), confirmation that zero features are missing any mandatory field
- For every non-haiku feature: one-sentence justification next to the feature ID
- Harness branch name: `harness/<HARNESS_ID>` (coordinator provisions the worktree)

### 2. progress.json — structured tracking

- Every feature with 7 specification fields + (specialist, llmTier, requiredSkills) trio + TDD phase tracking + dependencies

### 3. init.sh — environment validation

Repo-appropriate. Common patterns to include:
- Verify package manager dependencies installed — detect from the lockfile:
  - JS/TS: `npm install` / `pnpm install` / `yarn install` clean
  - Python: `pip install -r requirements.txt` clean, or `poetry install`, or `uv sync`
  - Ruby: `bundle install` clean
  - Go: `go mod download` clean
- Type-checker baseline:
  - JS/TS: `tsc --noEmit`
  - Python: `mypy <pkg>` or `pyright`
  - Go: `go vet ./...`
- Linter baseline:
  - JS/TS: `eslint .` or `biome check`
  - Python: `ruff check` or `flake8`
  - Ruby: `rubocop`
- Print the next pending feature from `progress.json`
- DO NOT assume any specific dev environment (no OrbStack, no Docker, no specific MCP) — let the actual repo dictate

### 4. pre-commit-validation.sh — quality gates

- Type check, lint, test using the repo's actual commands (read `package.json` scripts, `pyproject.toml`, `Makefile`, or equivalent)
- Schema drift if the repo has migrations
- Documentation sync if README/spec updates are required
- Progress JSON updated

### 5. session-log.txt — append-only session log template

---

## Required — anchoring against external strategic context

Strategic context is pulled in **harness-prep Step 1.5** (the standard read
bundle: `pm33_query_backlog filterTypes=['objective']`,
`pm33_query_features`, `pm33_competitive_threats`,
`pm33_voc_get_spike_alerts`, `pm33_voc_get_triage_queue`,
`pm33_query_backlog filterTypes=['epic']`). The planner's job here is to
**consume** the `## Strategic context` section of the discovery doc and
reflect it into the plan.

**Every plan README MUST contain a "Strategic context" section** with one of
two contents:

1. **The anchoring summary** — for each phase and feature, cite which
   objective it serves, which in-flight feature it coordinates with, which
   competitive pressure it addresses, and which VOC signal it answers.
   Features that anchor to *nothing* in the strategic-context bundle need
   a written justification ("infrastructure / refactor / non-strategic
   technical work") or they get reconsidered.

2. **The gap report** — if harness-prep Step 1.5 reported any failed or
   missing pulls, list them here verbatim. Use this template:

   > ⚠️ Strategic context partial: <missing domains>. The following pulls failed/returned-empty/were-skipped at planning time:
   > - `pm33_query_backlog filterTypes=['objective']` — <reason>
   > - `pm33_competitive_threats` — <reason>
   >
   > Planning accuracy may be reduced. Re-run with PM33 (or your work-tracking MCP) connected to refine.

Silent fallthrough — proceeding as if external context wasn't relevant —
is the failure mode this rule prevents. It is the same failure-shape as
the 2026-06-19 "Optional" framing that let planners ship roadmaps
contradicting active objectives.

**Skip rule** — for non-strategic technical work (CVE patch, dep upgrade,
RLS hardening, pure refactor with no user-visible change), strategic
context cannot inform "fix this bug correctly." The skip is legitimate;
document it once in the README's "Strategic context" section as
`✅ Skipped — non-strategic technical work. Rationale: <one sentence>.`
plus an Appendix B entry.

For PM33-specific clients: after the plan is approved, file the harness
epic via `pm33_create_work_item` and have specialists sync feature status
via `pm33_update_work_item` (using `pm33-mcp-queue` for disconnect
resilience).

---

## Phase 4 — gauntlet-review is MANDATORY

After drafting the plan, dispatch 3–5 parallel review specialists per the `gauntlet-review` skill. Minimum set for multi-workstream plans:

- `backend-architect` (service design, contract coherence)
- `security-auditor` (auth, permissions, external surfaces)
- `test-automator` (acceptance criteria coverage, regression)

Add when applicable:
- `ai-engineer` (any LLM / embedding / AI feature)
- `performance-engineer` (any cron / worker / scale concern)
- `frontend-developer` (any UI surface)

Integrate findings into the plan as Appendix A. **Plan is NOT complete** until Appendix A contains gauntlet findings and the plan has been re-sequenced (if needed) to address blockers.

---

## Success criteria — what a complete plan looks like

- [ ] harness-prep completed; discovery doc at `.harness/discovery/<slug>.md` (or override)
- [ ] gauntlet-review completed; findings in Appendix A
- [ ] 3–6 phases, each with 3–6 features (~1–2 hours each)
- [ ] Every feature has 7/7 specification fields
- [ ] Every feature has the `(specialist, llmTier, requiredSkills)` trio set
- [ ] Every frontend / ui-ux feature has `frontend-design:frontend-design` in `requiredSkills`
- [ ] Every frontend feature has `llmTier: opus`
- [ ] Every security-auditor feature has `llmTier: opus`
- [ ] Tier breakdown reported in README's Resource Plan (no target, just visibility)
- [ ] Non-haiku features have a one-sentence tier justification
- [ ] init.sh + pre-commit-validation.sh adapted to the actual repo (not assumed)
- [ ] README has a "Strategic context" section with EITHER the anchoring summary OR the gap report OR the legitimate-skip notice — never omitted (per §"Required — anchoring against external strategic context")
- [ ] If harness-prep was skipped (greenfield), rationale documented in Appendix B

---

## Anti-patterns

- ❌ Estimating effort before harness-prep completes
- ❌ Skipping gauntlet-review "because the plan is small"
- ❌ Using the deprecated combined `"agent": "haiku"` field (use the trio: `specialist` + `llmTier` + `requiredSkills`)
- ❌ Assigning sonnet/opus to "be safe" without a spec-justified reason
- ❌ Assuming PM33-specific (or any repo-specific) compliance sections apply universally — let the client's `CLAUDE.md` / `AGENTS.md` define their own standards
- ❌ Hardcoding paths to `pm-33-core`, OrbStack, specific npm scripts, or other repo-specific infrastructure
- ❌ Silent fallthrough when strategic context (PM33 or otherwise) was unreachable — always surface the gap

---

## Related skills

- **harness-prep** — Phase 0 orchestrator (discovery + brainstorming + conditional research). MANDATORY before this skill.
- **harness-discovery** — internal codebase audit. Composed by harness-prep.
- **harness-research** — bounded external research. Composed by harness-prep when triggered.
- **gauntlet-review** — Phase 4 parallel specialist review. MANDATORY after this skill.
- **harness-coordinator** — executes the approved plan.
- **harness-discipline** — TDD + progress tracking discipline for the specialists.
- **pm33-mcp** — optional PM33 context-integration layer (pull strategic context, push status). Compose explicitly if the user has it configured.
- **superpowers:brainstorming** — composed by harness-prep for the alternatives pass.
- **superpowers:writing-skills** — for skill authoring (not for harness planning).
