# Releasing the dual-target installer

This runbook releases the canonical `DeepWindAI/harness` artifacts first, then
allows a website preview to point `/install` at one exact asset. It never uses a
branch URL for executable content.

## Preconditions

- A reviewed commit is on the canonical repository's release branch.
- `release/keys/public-keyring.json` contains the active release key metadata
  and `release/keys/trusted-release-keyring.gpg` contains its matching public
  key. Neither file may be a placeholder or empty.
- GitHub Actions has `DEEPWIND_RELEASE_GPG_KEY_ID`,
  `DEEPWIND_RELEASE_GPG_PRIVATE_KEY`, and `DEEPWIND_RELEASE_GPG_PASSPHRASE`.
- The proposed tag is a new strict semantic version, for example `v1.2.3`.
- The website operator can set `DEEPWIND_INSTALL_RELEASE_VERSION` for a preview
  before production. This value is the version without the `v` prefix.

Do not publish or deploy if any prerequisite is missing. The workflow and
installer deliberately fail closed in that state.

## Canonical release first

1. Run the required installer matrix and release-contract tests on the tagged
   commit. Confirm the generated bootstrap is byte-identical to the reviewed
   version.
2. Trigger the canonical release workflow for the exact tag. It must publish:
   `deepwind-init-vVERSION.sh`, both target archives,
   `deepwind-release-manifest.json`, its detached signature, provenance,
   `public-keyring.json`, and `SHA256SUMS`.
3. Download the release assets from the tag-scoped GitHub Release URL. Verify
   the manifest signature with the reviewed `trusted-release-keyring.gpg`, then
   verify `SHA256SUMS`. Confirm the manifest's tag, bootstrap, both targets,
   source revision, and staging MCP allowlist.
4. Confirm neither the bootstrap nor manifest/provenance contains a mutable
   `main` URL. A release that cannot prove those facts is not publishable.

## Preview before production

1. Set `DEEPWIND_INSTALL_RELEASE_VERSION=VERSION` only on a website preview.
   Do not make the production setting yet.
2. Run the canonical smoke command against that preview:

   ```sh
   release/smoke-release.sh \
     --version VERSION \
     --website-url https://preview.example.com \
     --keyring release/keys/trusted-release-keyring.gpg
   ```

   It downloads the real immutable release assets, verifies signature and
   hashes, checks `/install` with both `HEAD` and `GET`, asserts the body is
   byte-identical to the versioned bootstrap, and confirms `/get-started` is
   browser HTML. It does not start OAuth or call a DeepWind data tool.
3. In a clean temporary non-root home, run the exact fetched bootstrap with
   `--version VERSION --target both`, then `--check`. Run the existing failed
   Codex-doctor fixture: it must report redacted status and leave all installed
   file hashes unchanged. Do not approve a real OAuth login as part of this
   release gate.
4. After preview evidence is recorded, set the same exact version in the
   production website environment, deploy, and re-run the smoke command against
   `https://deepwind.ai`. The website is not promoted when either smoke fails.

## Rollback

Rollback is a new website deployment with an explicit previously verified
version, never a rewrite to `main` and never a deletion of the canonical
release:

1. Select the previous release version from recorded successful smoke evidence.
2. Set `DEEPWIND_INSTALL_RELEASE_VERSION` to that exact version in a preview.
3. Run `release/smoke-release.sh` for the selected version against the preview.
4. Promote only after the preview is green; then repeat the smoke against
   production.

If a release asset, signing key, or website route cannot be verified, stop and
leave the previous production version intact.
