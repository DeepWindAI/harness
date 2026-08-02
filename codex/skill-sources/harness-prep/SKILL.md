---
name: harness-prep
description: Prepare evidence for a large engineering effort before planning. Use for Phase 0 discovery, strategic-context collection, alternative framing, and bounded research.
---

# Harness Prep

Produce a discovery artifact before asking a planner to create executable work. Do not implement the
goal in this phase.

## MCP boundary

Only the interactive root orchestrator may use an already-connected work-tracking connector.
Spawned explorers and later specialists have no connector authority. Give them the minimum returned
context they need, and ask them to return proposed status or decision updates to the root
orchestrator. If the connector is missing, disconnected, or returns incomplete data, record that
under `Inputs missing / unreliable`; never silently treat absent context as evidence.

## Output

Choose a stable lowercase slug and write:

```text
.harness/discovery/<slug>.md
```

Respect `HARNESS_ARTIFACTS_ROOT` when it is set. The document must contain:

1. Goal and success boundary.
2. Current implementation, partially implemented areas, and missing areas.
3. Relevant tests, release paths, deployment paths, and repository ownership.
4. Strategic context with source and retrieval date.
5. Inputs missing or unreliable.
6. At least three alternative approaches, including a recommendation and rejected options.
7. Bounded external research only where local evidence cannot answer a material question.
8. Risks, dependencies, open decisions, rough effort, and explicit out-of-scope items.

## Phase 0 workflow

### 1. Verify repository context

Read repository instructions and session context first. Record the current branch, dirty files,
relevant worktrees, build system, test commands, and deployment ownership. Preserve unrelated user
changes.

### 2. Audit the codebase

Split the audit into one to three independent surfaces. Use Codex sub-agent delegation when
available; otherwise inspect them inline. Every explorer prompt must:

- identify exact directories and questions;
- be read-only;
- prohibit connector calls and external writes;
- request file-and-line evidence;
- classify findings as built, partial, missing, or risky.

Parallel explorers may run only when their scopes do not overlap. Consolidate their evidence in the
root session.

### 3. Collect strategic context

The root orchestrator may perform a read-only strategic bundle if the configured connector is
available: objectives, active work, customer-signal spikes, competitive threats, triage, and recent
ideas. Record source IDs only when appropriate for the project artifact. Never send private
connector output to an explorer wholesale.

### 4. Frame alternatives

Generate at least three materially different approaches. Evaluate ownership, compatibility,
security, release safety, migration cost, and reversibility. Make the recommendation explicit.

### 5. Research selectively

Use external research only for unstable or unresolved facts. Prefer first-party documentation and
record links, retrieval date, and a 60–90 day revalidation date for fast-moving tooling.

### 6. Validate and hand off

Check that every assertion has local or cited evidence, every gap is visible, and no source file was
changed. Then hand the exact discovery path to the harness planner in the root session.

## Completion report

Return the discovery path, audit surfaces, sources used, missing inputs, recommendation, estimate,
and any decision that must be made before planning.
