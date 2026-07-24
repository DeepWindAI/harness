# Upgrade, recovery, and removal

## Upgrade safely

The public entry point is idempotent. Re-run it to install the latest verified
release for both targets:

```sh
curl -fsSL https://deepwind.ai/install | bash
```

Select a specific immutable release when a release operator has published it:

```sh
curl -fsSL https://deepwind.ai/install | bash -s -- --version 1.2.3
```

Preview the plan without writes:

```sh
curl -fsSL https://deepwind.ai/install | bash -s -- --dry-run
```

Check the current managed files without writes:

```sh
curl -fsSL https://deepwind.ai/install | bash -s -- --check
```

`--check` exits non-zero when a managed file is missing, changed, or would be
updated. That is drift information, not a reason to discard local work.

## Locally modified files and recovery

The installer compares managed files with `~/.deepwind/install/state.tsv`.
Unchanged files can be updated; locally changed files are preserved by default.
Review preservation messages and decide whether the local version or release
version should win.

If you intentionally want a release version to replace a local modification,
make a user-owned backup first, then run a scoped force upgrade:

```sh
mkdir -p "$HOME/deepwind-local-backup"
cp "$HOME/.codex/agents/harness-coordinator.toml" "$HOME/deepwind-local-backup/"
curl -fsSL https://deepwind.ai/install | bash -s -- --target codex --force
```

Adapt the copied path to every file you choose to replace. In addition to its
transaction rollback journal, the installer retains each successfully forced
replacement as a private timestamped file below
`~/.deepwind/install/recovery/`. The append-only
`~/.deepwind/install/recovery.tsv` records the backup digest, retained path,
and original destination. `--check` validates this recovery state and reports
the retained backup count without printing private paths. Restore from your
user-owned copy—or from a verified retained recovery record—and run `--check`
if you need to undo a successful forced replacement.

Retained recovery files are intentionally not pruned automatically. Inspect
their `recovery.tsv` records before removing any backup, and keep the state file
consistent with the recovery directory.

On failure the installer rolls back files changed in that run. If it reports
that manual repair is needed, preserve the reported recovery journal and do not
start another install until you have inspected the affected paths. Do not delete
the lock directory while a known installer process is running.

## Disable or remove Codex integration

There is intentionally no broad `--uninstall` flag: deleting paths from a home
directory without proving they remain managed and unmodified is unsafe.

To disable the release-contained Codex plugin, remove the plugin first:

```sh
codex plugin remove deepwind-harness@deepwind
```

Remove the `deepwind` marketplace only after confirming no other installed
plugin uses it:

```sh
codex plugin marketplace remove deepwind
```

Do not delete `~/.codex/agents/*.toml`, `~/.deepwind/install`, or Claude files
with a recursive command. Those locations may contain user changes or other
tools. Keep them in place unless you have compared each prospective deletion
with `~/.deepwind/install/state.tsv` and have a user-owned backup. A future
reviewed uninstall command may remove only unmodified, manifest-tracked files.

## Change targets

Installing only Claude leaves existing Codex files untouched, and vice versa.
Use `--target` to update the selected managed target; inspect with `--dry-run`
and `--check` when switching targets. This avoids destructive target
transitions and lets you retain a separate target’s working configuration.
