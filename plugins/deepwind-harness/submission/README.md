# DeepWind Harness public-plugin submission package

This directory contains the human-review materials for the public Plugins
Directory submission. The installable artifact is the `deepwind-harness`
plugin rooted one directory above this document.

## Listing summary

**DeepWind Harness** is a skills-only plugin for evidence-gated planning and
execution of complex engineering work. It provides four workflows: preparation,
planning, coordination, and engineering discipline. It is intended for
multi-workstream work that benefits from explicit quality gates, independent
review, isolated specialist execution, and a recorded evidence trail.

The plugin does not include an MCP server, connector, app, hook, OAuth flow,
credential store, telemetry, or network tool. It gives Codex reusable
instructions; filesystem and command permissions remain controlled by the
active Codex host and its approval policy.

## Submission fields

| Field | Value |
| --- | --- |
| Publisher | DeepWind |
| Plugin | `deepwind-harness` |
| Category | Developer Tools |
| Website | https://deepwind.ai/curriculum/harness-setup |
| Support | https://deepwind.ai/support |
| Privacy policy | https://deepwind.ai/privacy |
| Terms of service | https://deepwind.ai/terms |
| Source repository | https://github.com/DeepWindAI/harness |
| License | MIT |
| Capabilities | Read, Write |
| Authentication | None |

The manifest carries the same public URLs and ships DeepWind icon and light/dark
logo assets. The marketplace entry is retained for local and team testing; it
is not a claim that the plugin has already been listed publicly.

## Reviewer setup

1. Install the exact signed release containing the submitted plugin; do not
   review a mutable branch snapshot.
2. Enable the plugin in a new Codex session.
3. Use the self-contained prompts in [test-cases.md](test-cases.md). They need
   no account, private repository, API key, fixture service, or network access.
4. Confirm that the plugin supplies workflow guidance only and does not expose
   MCP tools, request credentials, or claim access to a DeepWind workspace.

## Draft release notes

Initial public listing of DeepWind Harness. The plugin packages four
skills-only workflows for preparation, planning, coordination, and delivery
discipline. It adds no external connector, MCP server, OAuth integration, or
background process.

## Publisher checklist

Before selecting **Submit for Review**, a DeepWind publisher with Apps
Management write access must verify the listing, legal links, selected regions,
and final signed release version in the OpenAI submission portal. Publication
remains a manual publisher action after OpenAI approval.
