# Codex installation and MCP boundary

## What the Codex target installs

The Codex target installs a release-contained plugin marketplace under
`~/.deepwind/install/share/codex-marketplace` and these managed role files:

- `~/.codex/agents/frontend-developer.toml`
- `~/.codex/agents/harness-coordinator.toml`
- `~/.codex/agents/harness-planner.toml`
- `~/.codex/agents/security-auditor.toml`

The enabled plugin is the only Codex skill surface. It bundles five formal
`deepwind-*` workflows, including `deepwind-gauntlet-review`; the installer
does not copy them into `~/.codex/skills`, `~/.agents/skills`, or repositories.
That prevents duplicate skill discovery and makes plugin versioning the single
Codex upgrade path.

The plugin bundle contains workflow skills and the public DeepWind MCP endpoint.
It does not contain OAuth credentials, hooks, applications, or a personal
marketplace configuration. The managed marketplace and plugin live together
below the verified release root so an upgrade can replace them atomically.

Install only the Codex target:

```sh
curl -fsSL https://deepwind.ai/install | bash -s -- --target codex
```

Plugin enablement is an explicit opt-in because Codex owns its user
configuration and plugin cache. Install the files and enable the verified
release-contained plugin in one command:

```sh
curl -fsSL https://deepwind.ai/install | bash -s -- \
  --target codex --enable-codex-plugin
```

The installer first inspects the configured `deepwind` marketplace. It refuses
to replace a marketplace with that name when it points outside the verified
release root. It then delegates configuration and cache changes to the Codex
CLI with fixed arguments; it never writes `~/.codex/config.toml` or a personal
`~/.agents/plugins/marketplace.json` directly.

The equivalent Codex plugin lifecycle commands are:

```sh
codex plugin marketplace add "$HOME/.deepwind/install/share/codex-marketplace"
codex plugin add deepwind-harness@deepwind
codex plugin marketplace list --json
codex plugin list --json
```

Start a new Codex thread after enabling or upgrading the plugin. The installer
does not enable it during an ordinary install. `--check` reports `enabled`,
`not-enabled`, `outdated`, or `conflict` and gives the corresponding opt-in or
repair action without changing Codex state.

## Optional DeepWind MCP OAuth

MCP configuration is a separate interactive action. It is never performed by
the default dual-target install. To register the staging server after Codex
files are installed, run this in a controlling terminal:

```sh
curl -fsSL https://deepwind.ai/install | bash -s -- --target codex --configure-mcp
```

Type the exact confirmation `yes` when prompted. Only after that confirmation
does the installer run fixed Codex commands for `deepwind` at
`https://app.deepwind.ai/mcp`. It suppresses their output, never reads or copies
`~/.mcp-auth`, and does not invoke DeepWind data tools.

If the terminal is not interactive, Codex is unavailable, consent is not
exactly `yes`, or OAuth does not finish, file installation remains successful
and MCP setup is skipped or reported as incomplete. Retry the explicit command
when you are ready.

## Doctor results

The installer’s doctor is advisory and non-fatal. It makes one local
`codex mcp get deepwind` status request and emits a short JSON status;
it does not authenticate, retry, read token files, or call a DeepWind data tool.

Possible statuses include `configured`, `not-configured`, `oauth-required`,
`connection-unavailable`, `no-workspace`, `cli-unavailable`, and
`command-error`. `no-workspace` means the installed harness is intact but the
authenticated DeepWind account has no usable workspace context. It is not an
installer failure; finish workspace provisioning and retry the explicit OAuth
flow if needed. Doctor output intentionally excludes workspace names, token
data, backlog contents, and raw CLI transcripts.

## Coordinator-only MCP policy

DeepWind MCP belongs only to the interactive parent coordinator. The parent may
make approved strategic reads and writes, and queues an authorized write after
one failed retry. Specialists, custom roles, and subagents do not receive MCP
credentials or connector configuration. They return requested strategic facts
or proposed status updates to the coordinator, which decides whether to make
the DeepWind call. This boundary applies even when a specialist can read the
installed workflow files.

For exact security behavior, see [MCP security](mcp-security.md).
