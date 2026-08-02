---
name: deepwind-gauntlet-review
description: Review a proposed multi-workstream engineering plan before implementation. Use for adversarial architecture, security, data, performance, operational, and testability review; consolidate evidence-backed findings and require fixes for blockers before execution.
---

# Gauntlet review

Run a bounded, independent review pass before implementation for plans with
multiple workstreams, elevated risk, or irreversible changes.

## Inputs

Require the plan, acceptance criteria, affected interfaces, verification plan,
and any discovery or research artifacts. State explicitly when an input is
missing; do not invent repository facts or external evidence.

## Review lanes

Select only the lanes relevant to the change:

1. Architecture and boundaries — ownership, interfaces, sequencing, rollback.
2. Security and privacy — authorization, tenant isolation, secrets, data flow.
3. Data and reliability — migrations, integrity, failure handling, recovery.
4. Performance and operations — load, observability, capacity, deploy safety.
5. Testability and delivery — acceptance criteria, reproducible verification,
   regression coverage, and independent review.

Use at least three independent lenses for a multi-workstream plan. Assign each
reviewer a focused remit and raw inputs; do not prime reviewers with a desired
answer. Do not grant specialists MCP credentials or connector configuration.

## Required output

For each lane, return:

- **Evidence inspected** — exact plan section, interface, or artifact.
- **Findings** — severity (`blocker`, `high`, `medium`, `low`) and why.
- **Required change** — concrete correction and owner/phase.
- **Verification** — local or provider-approved evidence that proves it.
- **Residual risk** — what remains after the proposed correction.

Consolidate duplicate findings. A blocker must be resolved in the plan before
execution; do not replace it with an untracked verbal note. Re-sequence phases
when a dependency or gate changes, and preserve the review record with the
plan.

## MCP boundary

The interactive coordinator may use an authorized DeepWind MCP connection for
project context. Specialists do not receive connector configuration,
credentials, or direct tool access; they return proposed findings and status
updates to the coordinator.

## Boundaries

Treat this as a review workflow, not permission to deploy or bypass tests. Use
local reproducible checks unless the repository explicitly names another
approved verification provider. Escalate missing authorization, unavailable
evidence, or material security uncertainty to the coordinator.
