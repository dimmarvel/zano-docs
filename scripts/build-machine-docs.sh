#!/bin/bash
# Documentation step for the Zano release build script.
# Replaces the old rm/--generate-rpc-autodoc/commit block: the RPC reference
# moved to api-reference/ and is versioned (see API-VERSIONING.md).
#
# Call it from the build script after the binaries are built:
#     bash /home/user/zano-docs/scripts/build-machine-docs.sh
#
# Everything it needs it derives itself, so no variables have to be exported:
#   * binaries      $daemon_path / $wallet_path if set, else the standard
#                   build output path (override with BUILD_SRC)
#   * version       read from the binary itself (`--version`), the source of
#                   truth for the version number and the network it was built
#                   for ("Zano v..." vs "Zano_testnet v...")
#   * BRANCH_NAME   decides WHICH docs version is written:
#                     release -> the published reference (rollover)
#                     develop -> the develop snapshot
#                   anything else is skipped; those are the only two branches
#                   that publish. The network is not a version any more, it is
#                   only used to reject a testnet binary on the release job.
#
# Env knobs: DOCS_DIR, BUILD_SRC, PYTHON, DRY_RUN=1 (generate + validate, no git writes).
# Requires: Python >= 3.5, stdlib only. The build machine is Ubuntu 16.04
# (python3 == 3.5.2), which is why api_version.py stays 3.5-compatible.

set -e

DOCS_DIR="${DOCS_DIR:-/home/user/zano-docs}"
BUILD_SRC="${BUILD_SRC:-/home/user/zano-custom-branch/build/release/src}"
ZANOD="${daemon_path:-$BUILD_SRC/zanod}"
SIMPLEWALLET="${wallet_path:-$BUILD_SRC/simplewallet}"
PY="${PYTHON:-python3}"

# Check the interpreter up front: an unsupported one otherwise surfaces as a
# bare SyntaxError from api_version.py, which reads like a broken script.
if ! command -v "$PY" >/dev/null 2>&1; then
  echo "ERROR: '$PY' not found — api_version.py needs Python >= 3.5 (set PYTHON=)" >&2
  exit 1
fi
if ! "$PY" -c 'import sys; sys.exit(0 if sys.version_info[:2] >= (3, 5) else 1)'; then
  echo "ERROR: $("$PY" -V 2>&1) is too old — api_version.py needs Python >= 3.5 (set PYTHON=)" >&2
  exit 1
fi

# Docs versions track branches: `release` is the published reference, `develop`
# is the preview snapshot. Nothing else publishes. An unset BRANCH_NAME (manual
# run) is treated as release, which is the historical behavior.
branch="${BRANCH_NAME:-release}"
case "$branch" in
  release|develop) ;;
  *)
    echo "BRANCH_NAME='$branch' is not a publishing branch (release|develop) — skipping docs update"
    exit 0
    ;;
esac

if [ ! -x "$ZANOD" ] || [ ! -x "$SIMPLEWALLET" ]; then
  echo "ERROR: binaries not found ($ZANOD / $SIMPLEWALLET)" >&2
  exit 1
fi

# the binary announces both its version and its network
version_line=$("$ZANOD" --version | awk '/^Zano/ { print; exit }')
version_core=$(echo "$version_line" | awk '{ print $2 }' | sed -e 's/^v//' -e 's/\[.*$//')
if [ -z "$version_core" ]; then
  echo "ERROR: could not parse version from: $version_line" >&2
  exit 1
fi
# The bracketed suffix carries the source commit: "2.2.1.506[16e457b-develop]".
# Only the develop label uses it: release and develop can sit on the same build
# number, so the number alone does not tell the two dropdown entries apart. The
# release label must stay a bare version — `check` asserts it is a substring of
# the page stamp, and "2.2.1.506 · eb86459" is not.
# The bracket content varies ("16e457b-develop", "testnet-76a791c", "eb86459"),
# so take the first hash-shaped run inside it rather than assuming a position.
version_commit=$(echo "$version_line" | sed -n 's/.*\[\(.*\)\].*/\1/p' \
  | grep -oE '[0-9a-fA-F]{7,}' | head -1)
case "$version_line" in
  Zano_testnet*) network=testnet ;;
  *)             network=mainnet ;;
esac

# The branch decides which docs version is written; the network is only checked.
# A testnet-config binary must never overwrite the published release reference:
# it exposes methods (start_mining/stop_mining) a release build does not, so
# that combination means the job is misconfigured.
if [ "$branch" = release ] && [ "$network" = testnet ]; then
  echo "ERROR: refusing to roll the release reference from a testnet binary ($version_line)" >&2
  echo "       the release job must build a mainnet-config binary" >&2
  exit 1
fi
echo "Writing documentation... ($branch branch, $network build, $version_core)"

cd "$DOCS_DIR"
if [ "${DRY_RUN:-}" != "1" ]; then
  git reset --hard
  git pull -r
fi

if [ "$branch" = develop ]; then
  develop_label="Develop (${version_core})"
  if [ -n "$version_commit" ]; then
    develop_label="Develop (${version_core} · ${version_commit})"
  fi
  "$PY" scripts/api_version.py snapshot --name develop \
    --zanod "$ZANOD" --simplewallet "$SIMPLEWALLET" \
    --label "$develop_label"
else
  # rolls the release version forward; crossing a release line
  # (e.g. 2.2.1 -> 2.3.0) auto-archives the outgoing release first
  "$PY" scripts/api_version.py rollover \
    --zanod "$ZANOD" --simplewallet "$SIMPLEWALLET" \
    --label "Release (${version_core})"
fi

"$PY" scripts/api_version.py check

if [ "${DRY_RUN:-}" = "1" ]; then
  echo "DRY_RUN=1 — generated and validated, no git writes"
  git --no-pager diff --stat
  exit 0
fi

git add -A
if git diff --cached --quiet; then
  echo "Docs unchanged for this build; nothing to commit"
else
  git commit -m "Auto generated doc (${version_core})"
  git push
fi
