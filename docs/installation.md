# Install DeepWind Harness

DeepWind supports macOS and Linux with Bash. Windows is not supported by this
installer release. Run it as your normal, non-root user in a terminal with a
canonical local home directory.

## One public entry point

Install both Claude Code and Codex assets (the default):

```sh
curl -fsSL https://deepwind.ai/install | bash
```

Install Claude Code assets only:

```sh
curl -fsSL https://deepwind.ai/install | bash -s -- --target claude
```

Install Codex assets only:

```sh
curl -fsSL https://deepwind.ai/install | bash -s -- --target codex
```

`--target` accepts `claude`, `codex`, or `both`; omitting it selects `both`.
The installer does not register an MCP server or start OAuth unless you later
add `--configure-mcp` for a Codex install.

## Inspect before executing

The first downloaded shell program is protected by HTTPS, but that is a **TLS trust boundary**: an attacker able to substitute that response can run code
before the release verifier starts. Inspect it when that risk is unacceptable:

```sh
curl -fsSL https://deepwind.ai/install | less
curl -fsSL https://deepwind.ai/install | bash -s -- --check
```

After bootstrap, the installer accepts only an exact strict-semver GitHub
Release. It verifies the release manifest against an embedded, versioned public
key and verifies every allowlisted archive digest before extracting it. It
rejects unsigned, unknown-key, expired, revoked, malformed, or digest-mismatched
release content and does not use `main` as a payload reference.

## Release trust

The generated bootstrap embeds the active public key committed in
`release/keys/public-keyring.json`. Release operators must provision matching
signing credentials before publishing; the workflow fails closed when the
private-key fingerprint differs or no active key is available. This does not
remove the bootstrap TLS trust limitation; it limits trust after bootstrap to
an immutable, verified release.

## Files and non-destructive behavior

The installer stages and verifies the complete selected release before it
changes managed destinations. It rejects unsafe archive paths and symlinks,
uses a lock, journals mutations, atomically replaces files, and rolls back
files changed by an interrupted or failed run.

Installed locations are:

- Claude agents, skills, and optional hook: `~/.claude/`
- Claude frameworks: `~/deepwind-frameworks/`
- Claude command: `~/.deepwind/bin/deepwind`
- Codex role TOMLs: `~/.codex/agents/`
- Codex release-contained marketplace and plugin: `~/.deepwind/install/share/codex-marketplace/`
- Installer state: `~/.deepwind/install/state.tsv`

Use a preview before an upgrade:

```sh
curl -fsSL https://deepwind.ai/install | bash -s -- --dry-run
```

Use `--check` to report drift without writing. A file changed since the last
managed version is preserved by default. Do not use `--force` until you have
reviewed every changed file. A successful forced replacement retains a private,
timestamped recovery copy under `~/.deepwind/install/recovery/` and records its
digest and original destination in `~/.deepwind/install/recovery.tsv`. Keep an
independent user-owned backup for important customizations; the retained copy
is a recovery aid, not a substitute for your backup policy. See
[upgrading and removal](upgrading.md).

## Optional Claude hook

The default Claude target includes its session hook. Omit it with:

```sh
curl -fsSL https://deepwind.ai/install | bash -s -- --target claude --skip-hooks
```

Restart Claude Code or start a new Codex thread after installation so newly
installed skills and roles are loaded.
