---
name: harness-research
description: "Bounded external research for harness planning. Use when evaluating a new library, touching a fast-moving domain (AI patterns, security, billing, compliance), or when the user explicitly asks for outside-codebase context. Default budget: 1 search-specialist agent + 3 WebSearch calls. Hard ceiling: 2 agents + 6 WebSearch calls. Findings are decay-tagged so stale citations don't get cargo-culted into future plans."
---

# Harness Research Skill

**Role**: BOUNDED EXTERNAL RESEARCHER — Fetches targeted outside-codebase context when the plan cannot be scoped without it

**Purpose**: Answer specific known unknowns about libraries, standards, or fast-moving domains. Strict budget prevents "one more search" sprawl and preserves the discovery skill's 120x ROI ratio. Default is NO research; this skill requires explicit justification to invoke.

---

## WHEN TO USE THIS SKILL

**Trigger conditions (any of these = research is warranted):**
- Evaluating a new library that is not already in `package.json` (e.g., "should we use library X or Y for Z?")
- Feature touches a fast-moving domain: AI API patterns, security advisories, compliance standards (SOC2/GDPR), billing rules
- User explicitly asks "what does the industry do for X?" or "is there a standard pattern for Y?"
- Planner cannot write a credible spec without knowing how an external API actually works
- Discovery doc has a gap item flagged as "unclear without external context"

**Skip conditions (default — no research needed):**
- Pure refactor with known cause and no external dependencies
- Bug fix where root cause is already understood
- Extending an obvious PM33 pattern (new Zod contract, new route, new migration)
- Time-pressured: deadline prevents waiting for search results
- Capability already exists in codebase and just needs wiring (harness-discovery handles this)

**Anti-pattern: "research just to be thorough."** The default is NO research. Discovery (harness-discovery) covers internal infrastructure. Research (this skill) covers external context for specific known unknowns only. If you cannot name the specific question you need answered, skip this skill.

---

## BUDGET (NON-NEGOTIABLE)

**Default**: 1 `content-marketing:search-specialist` agent + 3 WebSearch calls per harness

**Hard ceiling**: 2 agents + 6 WebSearch calls total

**Exceeding default**: requires citing the specific known unknown that justifies it (one sentence). Log in the plan.

**Exceeding ceiling**: STOP. Re-evaluate harness scope. If research needs exceed 2 agents + 6 searches, the harness is likely trying to solve an under-specified problem. Return to the user with a scoped question.

**Rationale**: 1 agent + 3 searches ≈ 80-95K tokens, 3-5 minutes of wall-clock time. The 120x ROI ratio from harness-discovery drops to ~300x at this budget — still strongly net-positive. Beyond ceiling, marginal return drops and synthesis time grows faster than the findings compound.

---

## HOW TO USE THIS SKILL

### Mode A — search-specialist for multi-source synthesis

Use when the question requires comparing 2+ sources (library comparison, competing standards, "what does the industry do?").

```typescript
Task({
  subagent_type: "content-marketing:search-specialist",
  description: "Research <specific topic>",
  prompt: `Research question: <one specific question that the plan needs answered>

Context: We are building <feature> for PM33 (TypeScript/Node.js/PostgreSQL/React).
The plan cannot proceed without knowing: <specific gap>.

Investigate:
1. <Specific sub-question 1>
2. <Specific sub-question 2>
3. <Specific sub-question 3> (max 3 per agent invocation)

Output format (under 600 words):
- Direct answer to the research question
- 2-3 sources with URLs
- Recommendation specific to PM33's stack
- One sentence on how quickly this area changes (helps set decay window)

Do NOT cover adjacent topics. Tight scope only.`
})
```

### Mode B — WebSearch for atomic fact lookup

Use when the question has a single definitive answer (current library version, specific API endpoint, exact compliance requirement).

```typescript
WebSearch({
  query: "<specific atomic query>",
  // Keep query narrow — the budget is 3 calls total
})
```

**Do not mix modes for one question.** If the question needs synthesis, use Mode A. If it needs a single fact, use Mode B. Running both for the same question wastes budget and produces duplicate findings.

---

## DECAY METADATA (MANDATORY)

Every research finding written to a discovery doc MUST include all three of these fields:

```markdown
**Research date**: YYYY-MM-DD
**Decays after**: YYYY-MM-DD
**Source**: <full URL>
```

**Default decay windows:**
- Fast-moving topics (AI API surfaces, security advisories, compliance rule changes): 30 days
- Library API surfaces and version-specific behavior: 90 days
- Standards with multi-year stability cycles (HTTP spec, SQL standard): 365 days

**Past the decay date**: the next reader MUST re-verify before acting on the finding. A decayed finding is not wrong — it may still be correct — but it cannot be trusted without re-verification. The reader should take 5 minutes to re-run Mode B before citing it.

**Why this matters**: the worst outcome is a future harness plan cargo-culting a year-old security recommendation as current. Decay metadata makes staleness visible at the point of consumption, not after the bug ships.

---

## OUTPUT LOCATION

Append all findings to the `## External research` section of the discovery doc for the current feature:

```
docs/dogfood/discovery/<feature-slug>.md
```

The `## External research` section MUST be clearly separated from the `## Findings by area` section (which contains harness-discovery's internal audit results). Future readers need to distinguish:
- **Findings by area** = verified internal, no expiry
- **External research** = external + dated, expires per decay metadata

Template for the section:

```markdown
## External research

> Research conducted: YYYY-MM-DD | Budget used: 1 agent + 2 WebSearch calls
> Hard ceiling: 2 agents + 6 calls. Budget remaining: 1 agent + 1 call.

### <Topic>

<Finding summary, 2-5 sentences>

**Research date**: YYYY-MM-DD
**Decays after**: YYYY-MM-DD
**Source**: <URL>

### <Topic 2> (if applicable)

<Finding summary>

**Research date**: YYYY-MM-DD
**Decays after**: YYYY-MM-DD
**Source**: <URL>
```

---

## ANTI-PATTERNS

**Don't:**
- Research when the question can be answered by reading the codebase — that's harness-discovery's job
- Invoke this skill without a named known unknown ("research the space generally" is not a trigger)
- Mix Mode A and Mode B for the same question
- Omit decay metadata — undated external findings are worse than no findings (false confidence)
- Exceed the hard ceiling without returning to the user for scope re-evaluation
- Run research after planning has started — research must complete before harness-planner drafts the plan

**Do:**
- Name the specific question before invoking the skill
- Log budget consumed in the discovery doc header
- Prefer Mode B (single WebSearch) over Mode A when the question is atomic — saves budget for harder questions
- Set conservative decay windows (30d for anything AI-related, 90d for library APIs)
- Summarize findings in under 600 words — planners need conclusions, not literature reviews

---

## RELATED SKILLS

**Workflow position** (discovery → brainstorming → research → planner → gauntlet):
```
harness-discovery         (Phase 0)    ← internal audit: what exists
superpowers:brainstorming (Phase 0.5)  ← 2-4 alternative framings (delegated from harness-planner)
harness-research          (Phase 0.6)  ← external context: what the industry does (conditional)
harness-planner           (Phase 1-3)  ← draft the plan informed by all the above
gauntlet-review           (Phase 4)    ← parallel specialist review before shipping
```

- **harness-discovery**: Covers internal infrastructure. Always runs first. Research is conditional — only when discovery leaves a named external gap.
- **harness-planner**: Consumes both the discovery doc and the `## External research` section. Planners should cite research findings by their decay date to signal whether re-verification is needed.
- **gauntlet-review**: Reviewers check whether cited research is still within its decay window. Expired findings in the plan are a review finding.
- **superpowers:brainstorming**: Conceptually similar — bounded creative/generative work with strict output constraints. Research asks "what does the industry know?" Brainstorming asks "what alternatives haven't we considered?" Both run between discovery and planning.

**Budget convention** comes from harness-coordinator's "Max 2 Node processes, 4GB" style — hard numeric limits in the frontmatter so they're visible at invocation, not buried in the body.

**Soft-cap parallel**: gauntlet-review's "default 3 reviewers, swap or add" is the same pattern — a stated default with a documented override condition, not a hard limit.

---

## CANONICAL EXAMPLE

**Session ff4cf7ec, 2026-05-26 — LSP-MCP scout**

A plan to expose Language Server Protocol features via MCP required knowing whether LSP-over-stdio vs LSP-over-HTTP was the current industry default for MCP integrations. This was a genuine external question that could not be answered by reading the PM33 codebase.

One search-specialist agent + 2 WebSearch calls (~600 words of findings, 2-3 sources, 5 minutes) produced a GO-narrow recommendation: LSP-over-stdio is the dominant pattern for IDE integrations; HTTP bridge is common for remote MCP servers. The harness plan was scoped to stdio-first with HTTP as Phase 2, avoiding a speculative HTTP-first design that would have required a rewrite.

Budget used: 1 of 1 default agents, 2 of 3 default searches. No ceiling approach.

---

**Skill Version**: 1.0
**Status**: PRODUCTION READY
**Created**: 2026-05-28
**Architecture decision**: split from harness-discovery per session ff4cf7ec specialist convergence. Combining with discovery would hide the distinct blast radius of external-vs-internal research. See harness-discovery SKILL.md lines 229-234.

Load this skill with: `Skill({ skill: "harness-research" })`
