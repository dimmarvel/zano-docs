# RPC API versioning — release runbook

The RPC reference (`/docs/build/rpc-api`) is a versioned Docusaurus instance
(pluginId `api`). Versions track **branches, not networks**: `release` is the
published reference (`api-reference/`, the "current" version, served at the base
URLs) and `develop` is the preview snapshot. Those are the only two branches
that publish. Snapshots live in `api_versioned_docs/`. The dropdown order below
"current" is `api_versions.json` and it is user-facing: **branch snapshots
first, then archives newest-first**. `scripts/api_version.py` maintains all of
this; don't hand-edit what it owns.

Our generation is authoritative. The team build machine may still commit into
`docs/build/rpc-api/` (excluded from the site, staging only); after a rollover
its commit must be a no-op against `api-reference/` — if it differs, diff it,
identify the generating build, and keep whichever is the newer release,
saying so in the commit message.

## Refresh the develop version (whenever a develop build is deployed)

    python3 scripts/api_version.py snapshot --name develop \
      --zanod <develop build>/src/zanod \
      --simplewallet <develop build>/src/simplewallet \
      --label "Develop (2.2.1.XXX)"

Normally the build machine does this for you on every develop build; run it by
hand only when reproducing or repairing a snapshot.

## Release rollover (HF6 and every release after)

1. `python3 scripts/api_version.py archive --name 2.2.1`   ← preserves the current release first; refuses on dirty tree (add `--refresh` to replace an archive that already exists)
2. `python3 scripts/api_version.py rollover --zanod <release zanod> --simplewallet <release simplewallet> --label "Release (2.3.0.XXX)"`
3. `python3 scripts/api_version.py check`
4. `npm run build` — must be green; spot-check the dropdown, banners, and a few method pages
5. Review `git diff` — the delta must match the release's expected API changes; update the changelog page
6. Commit (signed), PR, merge

## Build-machine integration

The release build script's old doc section (rm + `--generate-rpc-autodoc` into
`docs/build/rpc-api/` + commit) no longer works and must be replaced with
`scripts/build-machine-docs.sh` (drop-in; same variables: `$daemon_path`,
`$wallet_path`, `$version_str`). What changes in behavior:

- develop builds update the **Develop** snapshot instead of the release reference
- release builds roll the current version forward; crossing a release line
  (e.g. 2.2.1 → 2.3.0) auto-archives the old release first
- invariants are checked before committing; a no-change regen exits cleanly
  instead of failing on an empty commit
- requires python3 on the build machine (stdlib only)
- only `release` and `develop` builds update docs; every other `BRANCH_NAME` is
  skipped (this Jenkins setup sets `build_prefix=$BRANCH_NAME` on every build,
  so build_prefix cannot be used to tell builds apart)
- the branch decides which version is written; the binary's own version string
  supplies the version number, and no variables need exporting from the caller
- a testnet-config binary on the `release` job is refused outright: it would
  publish methods (start_mining/stop_mining) that a release build does not have
- `DRY_RUN=1` generates and validates without touching git

## Invariants `check` enforces (also safe in CI)

- four hand-written intro pages present in the working dir
- every listed version has its docs dir + sidebars json
- `api_versions.json` order: branch snapshots first, archives descending
- the "current" config label (Release) matches the stamp inside the generated pages
- no vestigial `_category_.json` at the instance root

## Notes

- The version dropdown renders only on `/docs/build/rpc-api/**`
  (`src/components/ApiVersionDropdown`) — the rest of the site is unversioned.
- Never fix typos in generated pages here; they live in the C++ `DOC_DSCR`
  strings upstream (hyle-team/zano) and regeneration clobbers page edits.
- Archives get an explicit config entry so every dropdown label reads
  `<name> (<build> · <commit>)`; path and the "unmaintained" banner match what
  Docusaurus would have defaulted to.
- A release line is archived twice: once while it is still current (so history
  exists early) and again automatically as it is superseded, which is the only
  moment its final build can still be read out of `api-reference/`. The second
  pass replaces the first, so the archive ends up holding what that line
  actually shipped last. `rollover` does this for you at a release boundary.
