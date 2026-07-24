---
name: harness-planner
description: Convert an approved DeepWind discovery artifact into an executable, resumable harness project with feature-level specifications and validation gates.
---

# Harness Planner

Plan only after Phase 0 produced a discovery document. Do not implement product code.

## MCP boundary

Planning is connector-independent. Use only strategic context already supplied by the interactive
root orchestrator. A planner sub-agent must not call work-tracking tools or attempt authentication.
Return proposed work-item changes to the root orchestrator.

## Required artifacts

Write one project directory:

```text
.harness/projects/<slug>/
├── README.md
├── progress.json
├── init.sh
├── pre-commit-validation.sh
└── session-log.txt
```

Use the discovery slug unless a collision requires a documented suffix. Respect
`HARNESS_ARTIFACTS_ROOT`.

## Plan design

Create three to six ordered phases. Each phase should contain three to six independently reviewable
features. Dependencies must form a directed acyclic graph. Split cross-repository delivery into
explicit features and release gates; never hide it in one feature.

Each `progress.json` feature must include:

- `id`, `title`, `status`, `phase`, `estimateHours`, and `dependencies`;
- `specialist`, `llmTier`, and absolute or release-portable `requiredSkills`;
- `tdd` states for `red`, `green`, `refactor`, and `delivery`;
- exact files, full function signature, algorithm, design reference, imports, test cases, and
  acceptance criteria;
- exact validation gates with expected success behavior.

Use `pending` for all new status and TDD fields. Use the least expensive model tier compatible with
the remaining judgment. Frontend and security work require the top tier. Multi-file work with real
design choices requires a plan-writing skill.

## Specialist mapping

Choose a role that owns the work:

- architecture, APIs, installer internals: backend architect;
- model behavior and agent instructions: AI engineer;
- UI and interaction: frontend developer plus frontend-design guidance;
- security, identity, permissions, release trust: security auditor;
- compatibility and regression matrices: test automator;
- public contracts and guidance: API documenter.

Do not combine model tier into the specialist field.

## Artifact requirements

`README.md` must state the goal, repository boundaries, product/security decisions, strategic
context and gaps, phase order, execution protocol, open gates, and an Appendix A reserved for the
adversarial review.

`init.sh` must perform read-only environment checks and fail clearly on missing prerequisites.
`pre-commit-validation.sh` must run deterministic project gates sequentially. Neither script may
mutate user configuration or fetch unpinned executable code.

`session-log.txt` starts with the discovery and planning evidence. It is append-only during
execution.

## Self-review

Before handoff:

1. Map every discovery requirement to at least one feature.
2. Search for placeholders and replace them with concrete instructions.
3. Verify names, signatures, paths, and dependency IDs are consistent.
4. Verify features do not overlap ownership.
5. Validate JSON and shell syntax.
6. Confirm implementation has not started.

Hand the project path to an adversarial review before coordination begins. Fold accepted findings
into `progress.json` and README Appendix A.
