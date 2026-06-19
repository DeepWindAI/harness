# DeepWind Harness for Claude Code

**Put your Claude Code in a harness.** Free harness for any Claude Code
project — outcome-attribution and the rest of the closed loop requires
a [DeepWind subscription](https://deepwind.ai/pricing).

This repo is the source of the bundle distributed at
[deepwind.ai/install](https://deepwind.ai/install). The curl-bash entry
point fetches directly from `main` of this repo via a Vercel rewrite, so
every commit here is live within 60 seconds of push.

## Two ways to install

### One-line (recommended)

```bash
curl -fsSL https://deepwind.ai/install/deepwind-init.sh | bash
```

Inspect before piping:

```bash
curl -fsSL https://deepwind.ai/install/deepwind-init.sh | less
curl -fsSL https://deepwind.ai/install/deepwind-init.sh | bash -s -- --check
```

### From this repo (for forks, air-gapped, or contribution)

```bash
git clone https://github.com/DeepWindAI/harness.git
cd harness
./install.sh
```

## What's in this bundle

```
agents/                          → ~/.claude/agents/
  ── DeepWind-authored ──
  harness-coordinator.md          Orchestrates multi-session harness work
  harness-planner-agent.md        Breaks complex projects into phased tasks

  ── Specialists (wshobson/agents, MIT) ──
  ai-engineer.md                  Production LLM apps, RAG, multimodal AI
  api-documenter.md               OpenAPI 3.1, SDK generation, dev portals
  backend-architect.md            REST/GraphQL/gRPC, microservices, scaling
  code-reviewer.md                AI-assisted review, security, performance
  database-admin.md               PostgreSQL, schema, RLS, ops
  frontend-developer.md           React 19, Next.js 15, accessibility
  performance-engineer.md         OpenTelemetry, load testing, Web Vitals
  security-auditor.md             OWASP, OAuth, compliance frameworks
  test-automator.md               AI-powered test automation, CI/CD
  ui-ux-designer.md               Design systems, wireframes, a11y
  LICENSE.wshobson                MIT license covering the 10 specialists

skills/                          → ~/.claude/skills/
  deepwind-mcp/                   DeepWind MCP tool conventions — LOAD BEFORE
                                  any deepwind_*/pm33_* tool call. Routing,
                                  known gaps, batch patterns.
  deepwind-mcp-queue/             Per-session queue-on-failure / drain-on-
                                  reconnect pattern for MCP writes that may
                                  span hours where the connection can drop.

  ── Phase 0: shrink uncertainty before planning ──
  harness-prep/                   Orchestrator entry point. Sequences
                                  discovery + strategic-context pull +
                                  brainstorming + conditional research into
                                  one enriched doc that harness-planner
                                  consumes. Run BEFORE harness-planner —
                                  skipping it is the root cause of 5-10x
                                  over-estimates in multi-workstream planning.
                                  Requires the superpowers plugin for
                                  brainstorming.
  harness-discovery/              Internal-audit pass — what already exists
                                  in the codebase that the plan can reuse?
  harness-research/               Bounded external research (max 1+3 search
                                  budget). Use only when the plan can't be
                                  scoped without external context.

  ── Phases 1+: planning, execution, review ──
  harness-planner/                Plans the harness from the prepared doc
  harness-coordinator/            Coordinator workflow rules
  harness-discipline/             TDD discipline for specialist agents,
                                  including Phase 0 environment verification
                                  (cwd / branch / agent ID match)
  gauntlet-review/                Multi-specialist antagonistic spec review
  feature-enhancements/           Pending-feature triage workflow

frameworks/                      → ~/deepwind-frameworks/
  HARNESS_PROJECT_TEMPLATE.md             Template + section-by-section guide
  LONG_RUNNING_AGENT_FRAMEWORK.md         The full framework spec (long read)
  HARNESS_TASK_DEFINITION_TEMPLATE.json   Per-task JSON skeleton

payload/                         → fetched by the installer
  mcp/deepwind.mcp.json           Hosted SSE entry merged into
                                  ~/.claude.json under mcpServers.deepwind
                                  (OAuth on first /mcp use — no token in
                                  config, no secret in the installer)
  hooks/session-start-deepwind-version-check.sh
                                  Optional version-check banner — once per
                                  day, fails open on network error, prompts
                                  only when remote > local strictly

CLAUDE.md.starter                Starter DeepWind-aware CLAUDE.md fragment.
                                 Copy into your project root (or merge with
                                 an existing CLAUDE.md) to get DeepWind
                                 conventions.

VERSION                          Source of truth for the version-check hook.
```

## After install — 5 steps

1. **Restart Claude Code** — newly installed agents, skills, and the version-check hook load on the next session.

2. **Install the `superpowers` plugin** so `harness-prep` can invoke `superpowers:brainstorming` for the always-on brainstorming pass:

   ```
   /plugin marketplace add anthropics/claude-plugins-official
   /plugin install superpowers
   ```

   Without `superpowers`, `harness-prep` skips brainstorming and warns — usable but degraded.

3. **Connect the DeepWind MCP server** so the agents can pull strategic context and push status updates:
   - In Claude Code: type `/mcp`
   - Pick **"DeepWind"** → complete the OAuth flow
   - You'll see `deepwind_*` tools appear (currently surfaced as `pm33_*` during the rebrand transition)
   - Before your first call each session, invoke `Skill({ skill: "deepwind-mcp" })` to load the conventions

4. **Copy the starter CLAUDE.md** into your project root:

   ```bash
   cp ~/deepwind-frameworks/CLAUDE.md.starter ./CLAUDE.md
   ```

   Then edit. Adds DeepWind conventions (harness discipline, gauntlet review, MCP tracking) to every session in that project.

5. **Try the harness flow** on a non-trivial project:
   - Say *"prep a harness for this"* — `harness-prep` sequences discovery + strategic-context pull + brainstorming + (conditional) research into one enriched doc
   - Then *"plan the harness"* — `harness-planner` consumes the prep doc
   - For multi-session execution, say *"resume as coordinator"* — the `harness-coordinator` agent takes the role

## What requires a DeepWind subscription

The harness is free. **Closed-loop capabilities** require a paid DeepWind subscription:

- Outcome attribution (AR(1) recalibration tied back to strategic objectives)
- Strategic-objective scoring + Brief alignment
- Capacity-aware sprint scheduler
- Audit log + tenant-isolated multi-workspace tracking
- The full Pam orchestrator + MCP tool surface (`deepwind_*` / `pm33_*`)

See [deepwind.ai/pricing](https://deepwind.ai/pricing).

## Version-check banner

After install, the version-check hook fires at every Claude Code session start. It hits this repo's `VERSION` file at most once per 24 hours and prints a stderr banner when a newer version is available:

```
[deepwind] new version available: 1.0.0 → 1.1.0
           update:  curl -fsSL https://deepwind.ai/install/deepwind-init.sh | bash
           changes: https://github.com/DeepWindAI/harness/releases/tag/v1.1.0
           silence: DEEPWIND_VERSION_CHECK=0
```

Comparison uses `sort -V` — only prompts when remote > local strictly, so dev/pre-release builds aren't nagged. Network failures cache for 1 hour so offline use doesn't hit GitHub on every session start.

Disable per-session with `DEEPWIND_VERSION_CHECK=0`, or skip the hook entirely with `--skip-hooks` at install.

## Attribution

The 10 specialist agents — `ai-engineer`, `api-documenter`, `backend-architect`, `code-reviewer`, `database-admin`, `frontend-developer`, `performance-engineer`, `security-auditor`, `test-automator`, `ui-ux-designer` — are from [**wshobson/agents**](https://github.com/wshobson/agents) (MIT). DeepWind redistributes this curated subset because every DeepWind project leans on them per `CLAUDE.md` agent-selection guidance. License terms: `agents/LICENSE.wshobson`.

For the full 75+ agent collection or the latest upstream versions, add the marketplace inside Claude Code:

```
/plugin marketplace add wshobson/agents
```

The DeepWind harness roles (`harness-coordinator`, `harness-planner-agent`) and all skills are DeepWind-authored.

## License

DeepWind-authored content (the 2 harness agents, 10 skills, frameworks, this README, the installer, hooks) is **MIT-licensed** — see `LICENSE`.

The 10 wshobson specialist agents retain their original MIT license (`agents/LICENSE.wshobson`).

## Updating

The curl-bash installer is idempotent — re-running upgrades in place:

```bash
curl -fsSL https://deepwind.ai/install/deepwind-init.sh | bash
```

…or `git pull` this repo + re-run `./install.sh`.

## Contributing

If you found a bug or want to suggest an improvement to a DeepWind-authored skill or agent, open an issue or PR here.

For the wshobson specialist agents, contribute upstream at [wshobson/agents](https://github.com/wshobson/agents).
