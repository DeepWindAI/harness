---
name: harness-discipline
description: Enforce isolated startup, RED-GREEN-REFACTOR-DELIVERY, progress tracking, and evidence reporting for a DeepWind harness specialist.
---

# Harness Discipline

Apply this skill as the assigned specialist. Maintain the specialist role in the dispatch; this skill
adds execution discipline.

## MCP boundary

Specialists have no work-tracking connector authority. Do not configure integrations, invoke remote
work-tracking tools, or inspect authentication state. Return strategic facts or proposed status
updates to the interactive root coordinator.

## Phase 0: bootstrap and verify

The dispatch must provide a working directory, branch, and stable agent ID. Before reading project
files:

1. Enter the exact worktree.
2. Export `HARNESS_AGENT_ID` to the dispatched value.
3. Run a repository-provided per-agent initialization script when present.
4. Verify `pwd`, `git branch --show-current`, the agent ID, `git rev-parse --show-toplevel`, and
   `git rev-parse --absolute-git-dir`.
5. Stop on any mismatch or protected branch. Never switch branches to repair a bad dispatch.

The git directory must identify a linked worktree rather than the repository’s shared main
worktree.

## Read context

Read the assigned feature, project README, recent session-log entries, relevant dependency commits,
repository instructions, and the files named by the specification. Confirm the working tree has no
unrelated changes before editing. If it does, report the overlap before proceeding.

## TDD cycle

### RED

Write the smallest focused test that expresses a listed acceptance criterion. Run it and capture
the expected failure. A passing test is not RED; strengthen or correct it before implementation.

### GREEN

Write the minimum implementation that makes the focused test pass. Use a real database for code
that executes database queries. Mocks are appropriate only at external boundaries or for pure
transformations.

### REFACTOR

Improve naming, structure, duplication, and error handling without expanding scope. Run the focused
test again and record the pass.

### DELIVERY

Run validation sequentially to prevent resource contention:

1. feature tests;
2. type or syntax checks;
3. lint/static analysis;
4. integration or packaging checks;
5. project pre-commit validation;
6. `git diff --check`.

Use no more than two test workers and stay within repository memory limits. Check for lingering test
processes after validation.

## Git delivery

Verify the exact branch again. Stage only the feature’s explicit paths; never use a broad add.
Review the staged diff, then create one feature commit. Do not amend or rewrite another agent’s
commit.

Progress artifacts may be updated only through the coordinator’s safe mechanism unless the dispatch
explicitly assigns those paths to the specialist.

## Escalation

Stop immediately for a security vulnerability, data-loss risk, destructive migration ambiguity, or
protected-branch mismatch. Report the evidence and required decision. Record non-blocking
maintainability or performance debt and continue only when the feature remains safe.

## Report

Return:

- feature ID and specialist role;
- files changed;
- RED failure and command;
- GREEN and REFACTOR pass commands;
- DELIVERY gates and results;
- test coverage when available;
- commit SHA;
- blockers, preserved user changes, and scope notes.

Evidence is required. Do not report a feature complete without a commit and passing gates.
