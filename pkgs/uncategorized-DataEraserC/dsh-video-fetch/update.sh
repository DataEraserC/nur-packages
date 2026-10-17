#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p git -p gnused -p coreutils -p nix-update -p prefetch-npm-deps
# shellcheck shell=bash
set -euo pipefail

# dsh-video-fetch update: GitHub release tag -> version + src hash, then the
# lockfile that ships inside the tag -> npmDepsHash. Unlike registry-tarball
# packages, no lockfile regeneration is needed: the source tag owns it, so
# --src-only plus one prefetch-npm-deps is the whole job.

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
NIX_FILE="$SCRIPT_DIR/default.nix"

# The flake's packages output flattens groups, so the runner's dotted
# attrPath (uncategorized-DataEraserC.dsh-video-fetch) must be stripped
# before it can be used as a flake attribute.
FLAT_PATH="${UPDATE_NIX_ATTR_PATH:-dsh-video-fetch}"
FLAT_PATH="${FLAT_PATH##*.}"

# Full tag list, not the releases atom feed (a tag without a release, or an
# unrelated tag crowding the feed, must not hide the newest version).
# The line-end anchor drops the `^{}` peeled entries.
NEW_VERSION=$(git ls-remote --tags https://github.com/DataEraserC/dsh-video-fetch.git 'refs/tags/v*' |
  sed -n 's#.*refs/tags/v\([0-9][0-9.]*\)$#\1#p' |
  sort -V |
  tail -1)
OLD_VERSION="${UPDATE_NIX_OLD_VERSION:-$(nix eval --raw ".#$FLAT_PATH.version")}"

if [ -z "$NEW_VERSION" ]; then
  echo "ERROR: no v<version> tags found upstream" >&2
  exit 1
fi

if [ "$NEW_VERSION" = "$OLD_VERSION" ]; then
  echo "Already at latest version $NEW_VERSION"
  exit 0
fi

echo "Updating dsh-video-fetch: $OLD_VERSION -> $NEW_VERSION"

# --src-only: version + src hash here, npmDepsHash from the new tag below
# (the runner's UPDATE_NIX_ATTR_PATH is the dotted path nix-update would
# fail to resolve against the flattened flake output, so unset it).
env -u UPDATE_NIX_ATTR_PATH nix-update "$FLAT_PATH" --version "$NEW_VERSION" --src-only --flake

SRC=$(nix build --no-link --print-out-paths ".#$FLAT_PATH.src")
NEW_HASH=$(prefetch-npm-deps "$SRC/package-lock.json")
sed -i "s|npmDepsHash = \"[^\"]*\";|npmDepsHash = \"$NEW_HASH\";|" "$NIX_FILE"

echo "dsh-video-fetch updated to $NEW_VERSION (npmDepsHash $NEW_HASH)"
