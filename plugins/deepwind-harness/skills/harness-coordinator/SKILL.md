---
name: harness-coordinator
description: Execute a reviewed DeepWind harness project by dispatching isolated specialists, enforcing evidence gates, and merging one feature at a time.
---

# Harness Coordinator

The coordinator reads coordination artifacts, dispatches implementers, reviews evidence, and merges
approved commits. It does not edit product source. If implementation is needed, dispatch a
specialist.

## MCP boundary

Only this interactive root coordinator may use an already-connected work-tracking integration.
Never delegate connector access, credentials, or connection setup. Specialists return strategic
information and proposed status updates in their reports. Queue non-critical write-backs during an
outage and continue connector-independent work; surface undrained updates in the final report.

## Startup

1. Read the project README, `progress.json`, and the last session-log entries.
2. Confirm the plan contains a completed adversarial review.
3. Inspect repository instructions, branch, worktrees, dirty state, and remotes.
4. Run the project `init.sh`.
5. Select the earliest pending feature whose dependencies are complete.
6. Mark only that feature in progress through the project’s safe progress-update mechanism.

Never begin from `main`, `master`, a production branch, or a dirty shared worktree.

## Dispatch

Use Codex sub-agent delegation with a concrete task name and bounded prompt. Give every specialist:

- an absolute isolated-worktree path;
- the exact expected branch and stable agent ID;
- the feature object from `progress.json`;
- required skill paths, beginning with harness discipline;
- relevant README decisions and dependency contracts;
- exact validation gates;
- a prohibition on connector/API calls not explicitly owned by the feature;
- a requirement to return files, RED/GREEN/REFACTOR/DELIVERY evidence, and commit SHA.

When delegation is unavailable, execute one clearly labelled specialist role inline while keeping
the coordinator from writing implementation itself.

Parallel work is allowed only for dependency-independent features with separate git worktrees and
separate indexes. Never share a writable worktree between implementers.

## Worktree and git policy

- Use `feature/harness/<project-slug>` for the integration branch.
- Use stable per-agent branches for a parallel wave.
- Resolve exact paths before any worktree command.
- Preserve unrelated changes.
- Stage explicit paths only.
- Verify the branch immediately before each commit.
- Merge a reviewed specialist commit with explicit staging and a descriptive message.
- Remove a specialist worktree only after its commit is merged and verified.

Do not use destructive reset or broad recursive deletion.

## Feature gate

Accept a specialist result only when:

1. All acceptance criteria are mapped to evidence.
2. RED failed for the intended missing behavior.
3. GREEN passed with minimal implementation.
4. REFACTOR kept the focused suite green.
5. DELIVERY gates passed sequentially.
6. The diff contains only the assigned feature.
7. Security/release findings are resolved or explicitly block the feature.
8. A commit SHA is provided and exists on the expected branch.

Request a focused correction from the same specialist when evidence is incomplete. Dispatch an
independent reviewer for security-sensitive or architecture-sensitive changes.

## Progress and recovery

After merge, atomically mark the feature completed, store validation evidence and commit SHA, and
append one session-log entry. On restart, trust committed artifacts and repository state rather than
conversation memory. Reconcile any `in_progress` feature with its branch and commit before
redispatch.

Do not mark a feature complete because time or context is low. Stop only for a real permission,
security, data-loss, or external-state blocker.

## Completion

Run the project pre-commit validation and the full release/compatibility gates. Confirm every
feature and TDD phase is completed, no worktree is left dirty, and all connector write-backs are
either completed or reported. Return merged SHAs, validation evidence, release blockers, and
remaining operational steps.
