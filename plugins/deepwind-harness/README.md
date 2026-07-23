# DeepWind Harness for Codex

This directory is a release-contained Codex plugin. It contains workflow skills only: no
credentials, hooks, apps, or connection manifests.

Copying this directory does not install or enable the plugin. Codex installs plugins from a
configured marketplace snapshot. The signed DeepWind release keeps this directory and
`.agents/plugins/marketplace.json` under one verified release root.

## Lifecycle contract

Set `DEEPWIND_RELEASE_ROOT` to the exact verified release directory that contains both
`.agents/plugins/marketplace.json` and `plugins/deepwind-harness`.

Fresh install and enable:

```sh
codex plugin marketplace add "$DEEPWIND_RELEASE_ROOT"
codex plugin add deepwind-harness@deepwind
```

Check:

```sh
codex plugin marketplace list --json
codex plugin list --json
```

An installer check succeeds only when the `deepwind` marketplace resolves to the managed release
root and `deepwind-harness@deepwind` is installed. It must not infer success from copied files.

Upgrade:

1. Verify and stage the complete new release.
2. Preserve locally modified managed files unless the user explicitly selects the force-and-backup
   path.
3. Atomically replace the managed release root.
4. Run `codex plugin add deepwind-harness@deepwind` again so Codex refreshes its installed snapshot.
5. Start a new Codex thread so the updated skills are loaded.

Removal:

```sh
codex plugin remove deepwind-harness@deepwind
codex plugin marketplace remove deepwind
```

Remove the marketplace only after confirming no other installed plugin depends on it. Remove the
managed release files only when their recorded digests still match; retain changed files and report
their paths.

The public installer owns these lifecycle seams. It must execute Codex commands with fixed arguments
and must never edit Codex configuration files or marketplace catalogs directly.
