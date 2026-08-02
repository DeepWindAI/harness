# DeepWind MCP security

The installer treats harness files and MCP authentication as separate actions.
The default command, including the default `--target both`, installs verified
files only. It does not register an MCP server, open a browser, read a
credential store, or authenticate.

Codex MCP onboarding requires all of the following:

1. The user passes `--configure-mcp`.
2. Codex is one of the selected install targets.
3. The process has a controlling terminal (`/dev/tty`); installer source may
   still arrive safely on standard input through the documented curl pipe.
4. The user types the exact confirmation `yes`.
5. The signed release manifest names alias `deepwind` and exact URL
   `https://app.deepwind.ai/mcp`.

Only then may the installer invoke these fixed commands:

```text
codex mcp add deepwind --url https://app.deepwind.ai/mcp
codex mcp login deepwind
```

The installer suppresses command output so tokens, authorization URLs, account
details, and workspace data cannot enter installer logs. It never reads,
copies, modifies, or attempts to share Codex's `~/.mcp-auth` OAuth cache.
Authentication belongs to the interactive coordinator. Child agents receive file-based
skills and roles with empty connector configuration; they must return proposed
strategic reads or writes to the coordinator.

The doctor is advisory and non-fatal. It performs one local
`codex mcp get deepwind` status check, sanitizes the output into one of
`configured`, `not-configured`, `oauth-required`, `connection-unavailable`,
`no-workspace`, `cli-unavailable`, or `command-error`, and discards the raw
text. It never retries, authenticates, reads token files, or invokes any
DeepWind data tool. A failed or unavailable MCP never rolls back installed
harness files.

The only configured endpoint in this release is the public app endpoint. The
retired staging and SSE connectors are not allowed fallbacks. Adding another
endpoint requires a separate reviewed configuration, signed-manifest contract,
and release.
