# DeepWind Harness

DeepWind Harness is a versioned workflow bundle for Claude Code and Codex.
It has one public shell entry point:

```sh
curl -fsSL https://deepwind.ai/install | bash
```

That command installs both supported targets by default. Choose one target with
`--target claude` or `--target codex`; see [installation](docs/installation.md).

The installer resolves an exact signed GitHub Release after the initial download.
It never installs a payload from `main`. The initial `curl | bash` download is
still a TLS trust boundary, so inspect it before execution when that boundary is
not acceptable:

```sh
curl -fsSL https://deepwind.ai/install | less
curl -fsSL https://deepwind.ai/install | bash -s -- --check
```

## Choose your guide

- [Installation](docs/installation.md) — targets, supported platforms, and trust model.
- [Codex](docs/codex.md) — plugin and role placement, optional staging OAuth, and doctor results.
- [Upgrading and removal](docs/upgrading.md) — checks, locally modified files, recovery, and safe disablement.
- [MCP security](docs/mcp-security.md) — exact OAuth and privacy boundaries.

## What is installed

Claude files are installed under `~/.claude` and supporting framework files
under `~/deepwind-frameworks`. The Claude target also installs a merge-gate —
`guarded-merge.sh` and its helpers under `~/.deepwind/bin`, plus a `PreToolUse`
hook registered in `~/.claude/settings.json` — that stops a coordinator from
self-merging an unreviewed, security-sensitive pull request (see
[installation](docs/installation.md#merge-gate)). Codex receives a release-contained plugin
marketplace under `~/.deepwind/install/share/codex-marketplace` and four
explicit role TOMLs under `~/.codex/agents`. Codex discovers the five formal
`deepwind-*` workflows only through the enabled release-contained plugin, so
the installer never duplicates them in `~/.codex/skills`, `~/.agents/skills`,
or project directories. Claude receives its target-specific aliases under
`~/.claude/skills`. The release manifest records every managed file; a modified
file is preserved unless the user explicitly chooses `--force`.

Codex plugin enablement is also explicit: add `--enable-codex-plugin` to the
installer command to let the Codex CLI activate the verified release-contained
marketplace and plugin.

The installer does not configure MCP by default, including when both targets
are selected. Optional Codex OAuth for `https://app.deepwind.ai/mcp` requires an interactive terminal,
`--configure-mcp`, and the exact confirmation `yes`. It never copies or reads
OAuth credentials. The interactive parent coordinator owns DeepWind MCP; child
agents receive file-based skills and return proposed strategic updates instead
of calling DeepWind.

## Release readiness

Public installation is fail-closed around the active public key committed in
`release/keys/public-keyring.json` and embedded in the generated bootstrap.
The release workflow must receive matching signing credentials; it refuses to
publish when the private key does not match that reviewed fingerprint. See
[installation](docs/installation.md#release-trust) for the bootstrap limitation
and release-verification model.

Every exact strict-semver release contains target-specific allowlisted archives,
a deterministic versioned bootstrap (`deepwind-init-vX.Y.Z.sh`), `SHA256SUMS`,
a deterministic `deepwind-release-manifest.json`, its detached signature,
provenance, and the versioned public keyring. The signed manifest records the
bootstrap filename, SHA-256 digest, and byte length alongside every archive's
filename, digest, byte length, normalized member paths, release revision,
channel, and endpoint alias. The installer never treats `main` as a payload.

## Development

Run the portable validation suite from a checkout:

```sh
tests/installer/run-shell-tests.sh
tests/doctor/run-shell-tests.sh
bash tests/plugin/test-codex-plugin.sh
bash tests/docs/test-installation-docs.sh
```

These tests use isolated temporary homes and fake CLIs; they do not authenticate
or call DeepWind data tools.
