#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git -p curl -p nix -p prefetch-yarn-deps -p common-updater-scripts
# shellcheck shell=bash
set -euo pipefail

DIR=$(dirname "$(readlink -f "$0")")
FILE="$DIR/motrix.nix"
REPO="https://github.com/Apps-Used-By-Myself/motrix"

OLD_REV=$(sed -n 's/^[[:space:]]*rev = "\([0-9a-f]*\)";/\1/p' "$FILE")
NEW_REV=$(git ls-remote "$REPO" HEAD | cut -f1)
[ -n "$NEW_REV" ] || {
  echo "Failed to query HEAD" >&2
  exit 1
}
[ "$NEW_REV" != "$OLD_REV" ] || {
  echo "motrix already at $NEW_REV"
  exit 0
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git clone --quiet "$REPO" "$TMP/r"
cd "$TMP/r"
depth=200
while ! tag=$(git describe --tags --abbrev=0 2>/dev/null || true); do
  if ((depth >= 10000)); then break; fi
  git fetch --quiet --tags --deepen=200 2>/dev/null || break
  depth=$((depth + 200))
done
date=$(git log -1 --format=%cs HEAD)
if [ -n "$tag" ] && [[ $tag == v* ]]; then tag="${tag#v}"; fi
if [ -z "$tag" ] || ! [[ $tag =~ ^[0-9] ]]; then NEW_VERSION="0-unstable-$date"; else NEW_VERSION="$tag-unstable-$date"; fi
cd - >/dev/null

echo "motrix: $OLD_REV -> $NEW_REV ($NEW_VERSION)"

# 1) Update version/rev/hash in the package file.
update-source-version "$UPDATE_NIX_ATTR_PATH" "$NEW_VERSION" --rev="$NEW_REV"

# 2) Refresh the vendored yarn.lock and its offlineCache hash.
curl -fsSL "https://raw.githubusercontent.com/Apps-Used-By-Myself/motrix/$NEW_REV/yarn.lock" -o "$DIR/yarn.lock"
NEW_HASH=$(prefetch-yarn-deps "$DIR/yarn.lock")
sed -i 's|^    hash = "sha256-[^"]*";|    hash = "'"$NEW_HASH"'";|' "$FILE"
echo "motrix yarn.lock refreshed"
