#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git -p common-updater-scripts
# shellcheck shell=bash
set -euo pipefail

DIR=$(dirname "$(readlink -f "$0")")
FILE="$DIR/hkdm.nix"
REPO="https://gitlab.com/postmarketOS/hkdm.git"

OLD_REV=$(sed -n 's/^[[:space:]]*rev = "\([0-9a-f]*\)";/\1/p' "$FILE")
NEW_REV=$(git ls-remote "$REPO" HEAD | cut -f1)
[ -n "$NEW_REV" ] || {
  echo "Failed to query HEAD" >&2
  exit 1
}
[ "$NEW_REV" != "$OLD_REV" ] || {
  echo "hkdm already at $NEW_REV"
  exit 0
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git clone --quiet "$REPO" "$TMP/r"
cd "$TMP/r"
tag=$(git describe --tags --abbrev=0 2>/dev/null || true)
date=$(git log -1 --format=%cs HEAD)
tag=${tag#v}
if [ -z "$tag" ] || ! [[ $tag =~ ^[0-9] ]]; then NEW_VERSION="0-unstable-$date"; else NEW_VERSION="$tag-unstable-$date"; fi
cd - >/dev/null

echo "hkdm: $OLD_REV -> $NEW_REV ($NEW_VERSION)"
update-source-version "$UPDATE_NIX_ATTR_PATH" "$NEW_VERSION" --rev="$NEW_REV"
# NOTE: ./Cargo.lock is committed and only rarely changes with new revisions;
# update it manually if a future revision pulls different crates.
