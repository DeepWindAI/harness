---
name: harness-discovery
description: "Audit existing PM33 infrastructure BEFORE drafting a harness plan or multi-workstream sprint. Use when an agent is about to estimate effort for any feature that touches existing code (anything other than greenfield). Prevents the 5-10x over-estimation that occurs when planners assume capabilities must be built from scratch when they actually already exist."
---

# Harness Discovery Skill

**Role**: PRE-FLIGHT AUDITOR — Maps what already exists before planning assumes what needs to be built

**Purpose**: Dispatch parallel codebase audits to set a realistic effort baseline. Outputs a discovery report consumed by harness-planner.

---

## 🎯 WHEN TO USE THIS SKILL

**Trigger conditions (any of these = MANDATORY discovery):**
- About to write a sprint plan, harness project, or feature spec touching existing code
- Asked to estimate effort for a capability where the user says "I think we already have most of this"
- Drafting a plan with effort estimate ≥ 8 hours per workstream
- Any feature that touches: VOC, harness, GitHub integration, OAuth/auth, AI/embeddings, work_items, ideas, billing, sync, or any other already-built subsystem
- Before invoking `harness-planner` for any non-greenfield work

**Skip conditions:**
- Truly greenfield work (new file in a new directory with no neighbors)
- Single-line bug fixes or one-shot operations
- Re-running a discovery that already completed in the same session

---

## ⚠️ THE LESSON THAT BIRTHED THIS SKILL

**Incident date: 2026-05-21**

A planning session estimated:
- `PAM-AUTO-HARNESS-001` at **10-12 hours** → actual was **3-4 hours** (90% already built)
- `PAM-GITHUB-PUBLISH-001` at **31-45 hours** → actual was **0-22 hours** (production-ready Path A existed)

Two parallel Explore agents (one per feature) found the truth in **~5 minutes total**. The 10-minute discovery saved ~50 hours of planning that would have shipped wrong. **The cost-benefit is so lopsided this should be reflexive, not optional.**

Recap: `docs/dogfood/2026-05-21-overnight-recap.md` UPDATE 4.

---

## 📖 HOW TO USE THIS SKILL

**Step 1 — Identify audit targets.** Before drafting any plan, list 1-3 distinct capability areas it touches. Examples:
- "Harness creation infrastructure" (services, MCP tools, templates)
- "GitHub publishing surface" (adapters, OAuth, workflow templates)
- "VOC auto-routing primitives" (classifier, embeddings, link suggestions)

**Step 2 — Dispatch 1-3 parallel Explore agents.** One per audit target. Use this template:

```typescript
Agent({
  subagent_type: "Explore",
  description: "Audit <capability> infrastructure",
  prompt: `Research thoroughness: very thorough.

Audit /Users/ssaper/Developer/pm-33-core for existing <capability> infrastructure.
The user/I am about to plan <feature/work>. Need an accurate map of what exists
before planning assumes what needs to be built.

**Specifically investigate:**
1. <Specific component / service / file>
2. <Adjacent component>
3. <Schema / DB tables>
4. <Workers / cron jobs / event listeners>
5. <Existing MCP/Pam tools in this area>
6. <Integration points with other subsystems>

**Output format (under 700 words):**
- ✅ What exists and is fully wired (file paths + line numbers + brief explanation)
- ⚠️ What exists but is partially wired (with what's specifically missing)
- ❌ What doesn't exist
- **Bottom line**: re-estimate the actual effort to close the gap.
  Show ORIGINAL guess and ACTUAL based on what you found.

Cite file paths and line numbers. Be specific. Don't speculate — if you can't find
something, say "not found".`
})
```

**Step 3 — Wait for parallel agent returns.** Each is typically 60-180s. Run multiple in a single message for parallelism.

**Step 4 — Synthesize into discovery doc.** Write findings to `docs/dogfood/discovery/<feature-slug>.md` with this structure:

```markdown
# Discovery: <feature-slug>

**Date**: YYYY-MM-DD
**Triggered by**: <what you were about to plan>
**Audit targets**: <list of capability areas audited>

## Findings by area

### Area 1: <name>
[Specialist agent's report inline OR linked]

### Area 2: <name>
[...]

## Corrected effort estimates

| Original guess | Audit-corrected | Delta |
|---|---|---|
| Workstream A: 31-45h | 0-22h | -23h |
| Workstream B: 10-12h | 3-4h | -8h |

## What this changes about the plan

[Resequencing, scope adjustment, deferred sub-features, etc.]

## What gaps remain

[Honest list of things that still need to be built]
```

**Step 5 — Feed discovery doc into harness-planner.** harness-planner skill expects this doc as input for Phase 0 (see updated harness-planner SKILL.md).

---

## 🏗️ WHAT THE DISCOVERY DOC PRODUCES

A `discovery/<feature-slug>.md` file with:
- ✅ **What's already shipped** (file paths, line numbers, brief explanation)
- ⚠️ **What's partially wired** (what's specifically missing per area)
- ❌ **What truly doesn't exist** (with rough effort to build)
- **Corrected effort baseline** for the planning phase

This doc is the **input** to harness-planner and the **basis** for gauntlet-review's "is this plan realistic?" check.

---

## 🎓 EXAMPLE INVOCATION

**User request**: "I want to plan auto-harness creation — Pam should spawn a harness when an idea is complex enough"

**Your response**:

```typescript
// Load skill
Skill({ skill: "harness-discovery" })

// Dispatch parallel audits (one message, two agents)
Agent({ subagent_type: "Explore", description: "Audit harness automation surface", prompt: `...harness coordinator + plan_harness + scaffolding + templates...` })
Agent({ subagent_type: "Explore", description: "Audit idea→PRD bridge surface", prompt: `...pm33_generate_prd + IdeasService.promote + existing bridge code...` })

// After agents return:
Write({ path: "docs/dogfood/discovery/auto-harness.md", content: "<synthesis>" })

// Then proceed to harness-planner with the discovery doc as input
Skill({ skill: "harness-planner" })
```

---

## ✅ SUCCESS CRITERIA

**A successful discovery includes:**

- [ ] 1-3 parallel Explore agents dispatched (NOT sequential — wastes time)
- [ ] Each agent given a clear, scoped audit target
- [ ] Each agent reports ✅ exists / ⚠️ partial / ❌ missing with file paths
- [ ] Synthesis doc written to `docs/dogfood/discovery/<slug>.md`
- [ ] Corrected effort estimates explicitly compared to original guesses
- [ ] Honest list of genuine gaps (not over-estimated, not over-dismissed)
- [ ] Discovery doc handed off to harness-planner as Phase 0 input

---

## 🚫 ANTI-PATTERNS

**Don't**:
- ❌ Skip discovery for "small" plans — the 2026-05-21 incident was for plans estimated at 10-45h each, all of which were 5-10x over
- ❌ Use a single Explore agent for multiple capability areas — parallelism is the point
- ❌ Treat the discovery doc as optional documentation — it's the input contract for harness-planner Phase 0
- ❌ Speculate when an agent says "not found" — that's a genuine gap, file it as such
- ❌ Re-run discovery on a capability that was already audited in the current session

**Do**:
- ✅ Discover before drafting — even when the user says "I think I know what's needed"
- ✅ Dispatch agents in parallel (single message, multiple Agent calls)
- ✅ Cite file paths and line numbers in the synthesis doc
- ✅ Show the corrected estimate vs original — make the savings visible
- ✅ Hand off to harness-planner with the discovery doc explicitly named

---

## 🔗 RELATED SKILLS

**Workflow position**: harness-discovery → harness-planner → gauntlet-review

- **harness-planner**: Consumes discovery doc as Phase 0 input. Does NOT proceed without it.
- **gauntlet-review**: Specialists reference discovery doc when reviewing the plan. Plan must be consistent with discovery's claim about "what exists."
- **harness-coordinator**: Receives the finalized plan and orchestrates implementation.

**Trigger flow**:

```
User describes feature
  ↓
harness-discovery (audit existing code)         ← THIS SKILL
  ↓ discovery doc
harness-planner (draft plan informed by discovery)
  ↓ plan doc
gauntlet-review (parallel specialist review)
  ↓ findings integrated
harness-coordinator (execute)
```

---

## 📚 REFERENCE DOCUMENTATION

- `/docs/dogfood/2026-05-21-overnight-recap.md` UPDATE 4 — incident that birthed this skill
- `/docs/dogfood/DOGFOODING_PROCESS.md` — canonical loop the discovery doc feeds into
- `/docs/dogfood/PHASE_5_SPRINT_PLAN.md` — first plan to use the discover→plan→gauntlet pattern; Appendix A shows what the gauntlet caught

---

## 🧠 WHY THIS WORKS

Discovery is a **cheap quality gate** that prevents the most expensive planning errors:
- Cost: ~10 minutes of agent dispatch time, ~5 minutes of synthesis
- Benefit (per 2026-05-21 incident): ~50 hours of over-estimated work corrected, ~12 hours of customer-facing bugs avoided

That's a **120x ROI** on the time invested. Make this reflexive for every non-trivial plan.

The pattern composes:
- **harness-discovery** (read) — what's there
- **harness-planner** (write) — what should be there
- **gauntlet-review** (critique) — is what should-be-there correct

Each phase has a different blast radius: discovery is research-only, planning is write-only, gauntlet is parallel-review-only. Combining them into one skill would hide that structure and make it impossible to invoke phases independently. Keep them separate; require composition via cross-references.

---

**Skill Version**: 1.0
**Status**: PRODUCTION READY
**Created**: 2026-05-21

Load this skill with: `Skill({ skill: "harness-discovery" })`
