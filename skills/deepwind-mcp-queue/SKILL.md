---
name: deepwind-mcp-queue
description: "Load via: Skill({ skill: 'deepwind-mcp-queue' }). Use when any agent on any repository writes to PM33 MCP over a session that may span multiple hours where the MCP connection can drop. Provides a per-session queue-on-failure / drain-on-reconnect pattern for pm33_create_work_item and pm33_update_work_item calls. Prevents silent backlog loss when the PM33 MCP server disconnects mid-session."
---

# PM33 MCP Queue Skill

**Role**: QUEUE MANAGER — wraps coordinator-level PM33 MCP calls so disconnects queue instead of silently failing.

**Scope**: `pm33_create_work_item` and `pm33_update_work_item` calls only. Does not apply to read-only calls (`pm33_query_backlog`, etc.).

---

## When to Use This Skill

Use when:
- Any agent writing to PM33 MCP (pm33_create_work_item or pm33_update_work_item) over a session that spans multiple hours where the MCP connection can drop
- The session may span multiple hours (PM33 MCP disconnects are common after 60-90 min)
- Status updates must survive a disconnect, preventing silent backlog loss

Do NOT use for:
- Read-only PM33 calls — let them fail naturally; they are retryable without state loss
- Single-call one-offs where the user is watching — surface the error directly instead
- Any non-PM33 MCP tool

---

## Queue File Location

One queue file per coordinator session. The filename embeds the session timestamp so parallel coordinators never collide:

```
.claude/pm33-mcp-queue-{session-id}.jsonl
```

Where `{session-id}` is derived at session start — use the harness ID + a short timestamp, for example:

```
.claude/pm33-mcp-queue-metric-align-002-20260604T143201.jsonl
```

The file path is relative to the repo root. If running inside a worktree (`.claude/worktrees/harness-*/`), resolve relative to the worktree root — the `.claude/` directory exists there too.

---

## JSONL Entry Shape

Each failed call appends exactly one line of JSON (no trailing commas, no line breaks within the object):

```json
{"timestamp":"2026-06-04T14:32:01.123Z","tool":"pm33_create_work_item","args":{...verbatim args object...},"reason":"MCP server unavailable: connection refused"}
```

Field rules:
- `timestamp` — ISO 8601 with milliseconds (`new Date().toISOString()` equivalent)
- `tool` — literal string `"pm33_create_work_item"` or `"pm33_update_work_item"`
- `args` — the exact args object you would have passed to the tool, verbatim
- `reason` — the error message or exception text from the failed call

---

## Try/Catch Pattern (Pseudocode — Apply Mentally Per Call)

Every coordinator-level `pm33_create_work_item` or `pm33_update_work_item` call follows this pattern:

```
attempt pm33_create_work_item(args):
  if success:
    continue — no queue entry needed
    on_first_success_after_failure: drain_queue()
  if catch MCP error:
    retry once (best-effort transient failure recovery)
    if retry succeeds:
      continue
      on_first_success_after_failure: drain_queue()
    if retry fails:
      append_to_queue(tool="pm33_create_work_item", args=args, reason=error_message)
      log to user: "PM33 MCP unavailable — queued for drain on reconnect"
      continue with work (do NOT block on PM33 sync failure)
```

Key principles:
- **PM33 MCP sync is best-effort** — a queued call never blocks work continuation or other operations.
- **Retry once before queuing** — this catches transient blips without accumulating false queue entries.
- **Queue is FIFO** — append to the file; drain from top.

---

## Drain Procedure

Drain is triggered by either reconnect signal (see next section). Drain runs synchronously before the next specialist dispatch.

```
procedure drain_queue(queue_file):
  for each line in queue_file (top to bottom):
    parse JSON entry
    attempt tool call: entry.tool(entry.args)
    if success:
      remove that line from queue_file
      log: "Drained: {entry.tool} args={summary}"
    if failure:
      stop draining — MCP still down
      log: "Drain stalled at entry {N} — will retry on next reconnect signal"
      return
  if queue_file is now empty:
    delete queue_file
    log: "PM33 MCP queue fully drained and removed."
```

Removing a line: rewrite the file without that line, or keep a pointer index. The simplest approach for a coordinator is to read all lines, replay them in order, and either delete the file on full success or rewrite only the remaining lines on partial success.

---

## Reconnect-Detection Signals

The coordinator watches for two signals that indicate PM33 MCP is reachable again:

**Signal A — Explicit user message**: The user's message contains the literal string `/mcp` or the word `reconnected` (case-insensitive). Treat this as a reconnect signal immediately. Attempt drain before the next action.

**Signal B — Subsequent successful PM33 call**: Any `pm33_*` call succeeds (including read-only calls). This means MCP is up. Attempt drain after that call completes.

When either signal fires: call `drain_queue()` with the current session's queue file path. If the file does not exist, no-op.

---

## Session-End Surface Requirement

At the end of every coordinator session (final summary to user), check whether the queue file exists and has entries.

If the queue file has entries:

```
WARNING: PM33 MCP queue has {N} pending entries that were not drained this session.
File: .claude/pm33-mcp-queue-{session-id}.jsonl

First 3 entries:
  1. {tool} @ {timestamp} — args summary: {id or title if present}
  2. ...
  3. ...

To drain: reconnect PM33 MCP (/mcp) at the start of the next session.
The queue file will auto-drain on the first successful PM33 call.
```

If the queue file does not exist or is empty: no mention needed.

---

## Coordinator Integration Checklist

When adopting this skill in a coordinator session:

- [ ] Derive session ID from harness ID + timestamp at session start
- [ ] Note queue file path: `.claude/pm33-mcp-queue-{session-id}.jsonl`
- [ ] Wrap every `pm33_create_work_item` and `pm33_update_work_item` call with try/catch + retry-once
- [ ] On catch after retry: append JSONL entry, continue harness work
- [ ] On reconnect signal (user /mcp message or successful PM33 call): drain queue
- [ ] In session-end summary: surface queue count if non-zero

---

## What This Is NOT

- Not durable infrastructure — the queue file is ephemeral per session. If the session ends without drain, the file persists for the next session to pick up, but there is no automatic background agent watching it.
- Not a retry/backoff system — drain is manual (triggered by reconnect signal), not timed.
- No Redis, BullMQ, or external job system — this is a plain JSONL file in the repo.
- Not a replacement for MCP reliability improvements — this is a coordinator-layer convenience pattern.

---

## Reference

### PM33-Internal References
- Work item: `1638c7aa-bbd1-460d-9bb4-710882161682` (PM33-MCP-QUEUE-AUTO-BACKFILL-001)
- Parent epic: `87e0f23e-79b7-4e1c-bc84-79a8592f10a4` (CONTRIB-PROVENANCE-001)

### Related Skills
- **pm33-mcp**: The broader PM33 context-integration skill. Covers context-pull (strategy/OKRs/competitors/VOC) and context-push patterns. This skill (pm33-mcp-queue) is the disconnect-resilience layer for the write path.

### Patterns
- This skill replaces the manual `docs/memory/queued-pm33-calls-*.md` pattern with an automated queue mechanism.
