---
name: deepwind-mcp
description: "Conventions for working with PM33 MCP tools (mcp__pm33-staging__*). Invoke BEFORE the first pm33_* tool call in a session. Covers tool routing, the remaining open gaps (5000-char description cap, MCP intermittent disconnect, em-dash/unicode title rejection, etc.), batch-creation patterns, audit-epic UUIDs, and the queue-and-execute pattern for MCP instability. Use when: filing work items, querying backlog, splitting epics, syncing local idea registries, running optimize_priorities, or any task involving pm33-staging MCP tools."
---

# PM33 MCP — Working Conventions

**Purpose**: PM33 dogfoods itself. Agents touch `mcp__pm33-staging__*` tools constantly — to file tech-debt items, query the backlog, run prioritization, split large epics, sync local idea registries. This skill captures the conventions and pitfalls so each session doesn't rediscover them.

**Invoke when**: about to call any `pm33_*` tool, or coordinating work that will need to.

---

## 1. Tool routing — what to use when

| Goal | Tool | Notes |
|---|---|---|
| Create a work item (epic/story/task/bug) | `pm33_create_work_item` | Description capped at 5000 chars (gap #2). |
| Create a Brief (structured agentic unit) | `pm33_create_brief` | Preferred over `create_work_item type='story'` for agent-dispatched work. F11.2 (PM33-CREATE-PATH-GAPS-001 gap #1) shipped 2026-05-28. |
| Update priority/status/description | `pm33_update_work_item` | Use to bump priority, close parent on split, change description. |
| Query backlog | `pm33_query_backlog` | Use `mode: 'full'` to include terminal items; `columns: 'identity'` for ID lookups; `limit: 200` max per page. |
| Find an existing epic | `pm33_query_backlog filterTypes=['epic'] mode='full' columns='identity' limit=200` | Anti-duplication step before any `create_work_item` for an epic. |
| Link epic to feature | `pm33_link_epic` | `(featureId, epicId, tenantId, workspaceId, source)`. |
| Link epic to objective | `pm33_link_objective` | Shipped 2026-05-28 (PM33-CREATE-PATH-GAPS-001 gap #7 closed). |
| Run prioritization | `pm33_optimize_priorities` | WSJF/RICE/ICE/MoSCoW. Alignment factor uses canonical `epic_objective_links` data (per ALIGN-CONSOLIDATE-001, 2026-05-21). |
| Score strategic alignment | `pm33_score_alignment` | Primary path uses canonical `epic_objective_links` lookup; AI fallback only when no link row exists (returns `score: null` + `objectiveCount: 0` to signal "AI-only, not linked"). Trust the numeric score; do NOT trust the bucket when `score: null`. |
| Plan a harness | `pm33_plan_harness` | Requires `prdId`, NOT `epicId` (gap #8 — chain via `pm33_generate_prd` first). |

---

## 2. Known gaps — PM33-CREATE-PATH-GAPS-001 (epic `2dbe553d-7742-4421-9788-c865db7f3cfc`)

Captured during 2026-05-26 AGENT-VISIBILITY-001 filing. Status as of 2026-05-28:

| # | Gap | Workaround |
|---|---|---|
| 1 | ~~No `pm33_create_brief` MCP tool~~ | ✅ **CLOSED 2026-05-28** — use it directly. |
| 2 | `description` field capped at **5000 chars** | Compress; put spec details in `docs/design/<feature>.md` and link. |
| 3 | No `strategicObjectiveIds: uuid[]` on `create_work_item` | Use `pm33_link_objective` post-create. |
| 4 | No native `audience`, `agent_sources`, `harness_candidate`, `mockup_url` fields | Stuff into description YAML; planner agents can't currently parse. |
| 5 | Tool discovery requires human OAuth | First-time agents need `/mcp` interactive flow. |
| 6 | ~~`pm33_score_alignment` = keyword similarity, NOT objective binding~~ | ✅ **CLOSED 2026-05-26** (investigation in session ff4cf7ec) — code was refactored by ALIGN-CONSOLIDATE-001 (2026-05-21) + ALIGN-CHAT-PATH-001 (2026-05-22) + CLOSED-LOOP-WORKFLOW-001 B.2 fix. Primary path now reads canonical `epic_objective_links` via `loadCanonicalAlignmentForEpics`. AI fallback only when no link row exists and explicitly returns `score: null` + `objectiveCount: 0` (consumers must differentiate null vs numeric). Numeric scores ARE canonical and trustworthy. |
| 7 | ~~No `pm33_link_objective` primitive~~ | ✅ **CLOSED 2026-05-28** — use it directly for epic→objective binding. |
| 8 | `pm33_plan_harness` requires `prdId`, refuses `epicId` | Chain: epic → `pm33_generate_prd` → PRD → `pm33_plan_harness`. |
| 9 | **MCP intermittent disconnect** | See §5 below — queue-and-execute pattern. |

---

## 3. Common patterns

### Filing a single work item

```js
pm33_create_work_item({
  title: "<ID> — <one-line title>",  // ID-first so search-by-ID works
  type: "bug" | "story" | "task" | "epic" | "improvement" | "brief",
  priority: "critical" | "high" | "medium" | "low" | "none",
  storyPoints: <0-100>,               // omit for harness-tier epics
  status: "backlog",                  // default; "in_progress" for active work
  epicId: "<parent-uuid>",            // optional — file under an existing epic
  description: "<≤5000 chars>",       // hard cap
})
```

### Filing a batch (parallel)

Send 4-8 `pm33_create_work_item` calls in a SINGLE message. Don't loop sequentially — MCP handles parallel fine when stable. Above ~10 calls in one parallel block, chunk into groups of 4-5.

### Splitting a large epic into sub-items

When `pm33_optimize_priorities` ranks a critical 13-SP epic at P3-Low because of job-size penalty, split:

1. `pm33_create_work_item` × N (the children), each under the same epic
2. `pm33_update_work_item({ workItemId: parent, status: "done", description: "... split into N sub-bugs. Children: <uuids>" })`

The optimizer then ranks each child on its own merit. See STRAT-EXTRACT-001 (parent `fd1503ab-...`) split into 4 sub-bugs 2026-05-27 for the canonical example.

### Anti-duplication before filing

Always query existing epics by ID-token before filing:
```js
pm33_query_backlog({ filterTypes: ["epic"], mode: "full", columns: "identity", limit: 200 })
```
Then grep results for the ID. If a similar title exists, link to the existing UUID instead of creating a duplicate. False positives (wrong link) are much worse than false negatives (duplicate that can be merged later).

---

## 4. Canonical parent UUIDs

| Epic | UUID | Purpose |
|---|---|---|
| AUDIT-DOCUMENTED-UNADDRESSED-001 | `473e08b2-87f1-4ad2-8bb3-7c6771869746` | Parent for tech-debt audit children (2026-05-26 sweep). |
| PM33-CREATE-PATH-GAPS-001 | `2dbe553d-7742-4421-9788-c865db7f3cfc` | The 9-gap inventory above. |
| OPTIMIZER-TECHNICAL-RISK-FRAMEWORK-001 | `2b48ec6a-6e9f-4ec6-8f53-a3caa3cb75d2` | 5th prioritization framework spec (standalone). |
| Pam Discoverability | `19752da5-b02c-44b2-8a47-dcb1a7bcf190` | Parent for Pam UX work. |
| PaM Tool Hardening — Phase 2 | `2e4e4fd9-7f65-4801-8b95-37a866c9953a` | Parent for incident-driven Pam tool fixes. |
| AI Promotion Pipeline (E2) | `9b45a82b-e275-4e4c-86b8-f2c7662c3cb2` | Idea → Feature → Epic orchestration. |
| Briefs (E11) | `e63958f3-6afb-4c5e-b7ec-d85594b9c123` | Category differentiator. |

For tech-debt audit items: file under `473e08b2`. For optimizer/framework infrastructure: standalone, no parent (acceptable). For Pam tool fixes: under `2e4e4fd9`.

---

## 5. MCP instability — queue-and-execute pattern (gap #9)

`pm33-staging` MCP drops mid-call ~once per 10-20 calls in a session. Patterns to absorb this:

### When MCP drops mid-batch

1. Don't retry the failed call immediately — the session is gone. Tools must be re-loaded.
2. Capture what's still pending in a memory file: `~/.claude/projects/-Users-ssaper-Developer-pm-33-core/memory/queued-pm33-calls-<date>.md`. Include the exact `pm33_*` call shape for each pending item.
3. Continue with MCP-independent work (markdown surgery, file edits, commits).
4. When user runs `/mcp` to reconnect, re-load tool schemas via `ToolSearch query="select:mcp__pm33-staging__pm33_create_work_item,..."`, then drain the queue.
5. Delete the memory file once drained.

See `memory/queued-pm33-calls-2026-05-27.md` for the canonical example (17 epics queued during a single sync).

### When MCP loads but tools aren't directly callable

After `/mcp` reconnect, tool *names* are visible in the deferred-tools list but schemas are NOT loaded. Direct calls return `No such tool available`. Load schemas first:

```
ToolSearch query="select:mcp__pm33-staging__pm33_create_work_item,mcp__pm33-staging__pm33_update_work_item,mcp__pm33-staging__pm33_query_backlog" max_results=3
```

Then call normally. The first call after a fresh reconnect may also return `Session not found. Please re-initialize.` — retry once and it works.

### Subagents can't reuse parent's MCP auth

Dispatching a subagent that needs PM33 MCP tools won't work — the subagent gets its own OAuth context and prompts for re-auth. Either do PM33 calls in the parent session, OR have the subagent do MCP-independent work and the parent handle MCP calls.

---

## 6. Filing tech-debt vs feature work

| Source | Where to file |
|---|---|
| TECHNICAL_DEBT.md OPEN entry | PM33 work item under audit epic `473e08b2-...`. Add `**PM33**: <uuid>` back to the markdown entry. |
| TECHNICAL_DEBT.md OPEN entry that's actually shipped (stale Status) | Update markdown Status to RESOLVED with closure reason. Don't file in PM33. |
| `docs/design/PENDING_FEATURE_ENHANCEMENTS.md` entry (DESIGN/APPROVED) | PM33 epic (standalone or under appropriate roadmap epic). Add `**PM33**: <uuid>` back to the registry entry. |
| `docs/dogfood/discovery/<slug>.md` | Most have epics already. Check via title-grep against existing epic list before filing. |
| Validation-discovered bug | Fix inline if small; OR file via PM33 if larger. Never punt to "we'll fix later" (see `feedback-no-deferred-fixes.md`). |

Per `feedback-log-tech-debt-via-pm33-mcp.md`: **PM33 is primary, markdown is fallback** when MCP is unavailable.

---

## 7. Field-encoding conventions

| Markdown sources use | Convert to PM33 |
|---|---|
| "P0" or "critical" | `priority: "critical"` |
| "P1" or "high" | `priority: "high"` |
| "P2" or "medium" | `priority: "medium"` |
| "P3" or "low" | `priority: "low"` |
| "30 min" | `storyPoints: 1` |
| "few hours" | `storyPoints: 2` |
| "1 day" | `storyPoints: 5` |
| "2-3 days" | `storyPoints: 8` |
| "1 week" | `storyPoints: 13` |
| "2-3 weeks" | `storyPoints: 21` |
| ">1 month" | epic, omit `storyPoints` |

---

## 8. Always do, never do

**Always**:
- Search existing epics by ID-token before filing (anti-duplication).
- Put the markdown ID as the FIRST token of `title` (e.g. `"VEL-ATTR-LANE-ID-NULL-001 — Three sprint_items insert paths..."`). Enables future text-search recovery.
- Capture the returned UUID and write it back to the source markdown.
- Use the audit epic `473e08b2` for tech-debt sweep children. Optimizer/framework work: standalone.
- Treat `pm33_score_alignment` results as advisory.

**Never**:
- Skip the anti-duplication query — duplicates are expensive to merge.
- File when the user/triage says "stale, code shows fix landed" — update the markdown Status instead.
- Trust the description if it exceeds ~4800 chars before encoding overhead — verify length first.
- Loop `pm33_create_work_item` sequentially if you can parallelize 4-8 calls per message.
- Chain `pm33_plan_harness` directly from an epic — go via `pm33_generate_prd` first (gap #8).

---

## 9. Reference incidents

- **2026-05-26 AGENT-VISIBILITY-001 filing** — surfaced the 9 gaps in PM33-CREATE-PATH-GAPS-001. See `docs/design/AGENT_VISIBILITY_001_SPEC.md`.
- **2026-05-27 tech-debt audit** — 25 P0/P1 entries filed under epic `473e08b2`, 280 RESOLVED entries archived. See PR #157.
- **2026-05-27 STRAT-EXTRACT-001 split** — canonical example of "13-SP critical ranks P3 due to job size, must split." See PR #189.
- **2026-05-27 idea-registry sync** — 17-epic batch blocked by MCP instability, queued in memory. See `queued-pm33-calls-2026-05-27.md`.

---

**One-liner**: "PM33 MCP is dogfood-grade — fast when stable, brittle at scale, descriptions short, alignment lies. Plan around the gaps, queue when it drops, anti-dup before you file."
