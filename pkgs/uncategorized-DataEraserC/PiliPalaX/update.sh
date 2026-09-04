#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git -p curl -p nix -p python3 -p python3Packages.pyyaml -p common-updater-scripts
# shellcheck shell=bash
set -euo pipefail

DIR=$(dirname "$(readlink -f "$0")")
FILE="$DIR/PiliPalaX.nix"
REPO="bggRGjQaUbCoE/PiliPlus"
PREFIX=""

OLD_REV=$(sed -n 's/^[[:space:]]*rev = "\([0-9a-f]*\)";/\1/p' "$FILE")
NEW_REV=$(git ls-remote "https://github.com/$REPO" HEAD | cut -f1)
[ -n "$NEW_REV" ] || {
  echo "Failed to query HEAD of $REPO" >&2
  exit 1
}
[ "$NEW_REV" != "$OLD_REV" ] || {
  echo "PiliPalaX already at $NEW_REV"
  exit 0
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git clone --quiet --filter=blob:none "https://github.com/$REPO" "$TMP/r"
cd "$TMP/r"
depth=200
while ! tag=$(git describe --tags --abbrev=0 2>/dev/null || true); do
  if ((depth >= 10000)); then break; fi
  git fetch --quiet --tags --deepen=200 2>/dev/null || break
  depth=$((depth + 200))
done
date=$(git log -1 --format=%cs HEAD)
if [ -n "${PREFIX}" ] && [[ $tag == "${PREFIX}"* ]]; then tag="${tag#${PREFIX}}"; fi
if [ -z "$tag" ] || ! [[ $tag =~ ^[0-9] ]]; then
  NEW_VERSION="0-unstable-$date"
else
  NEW_VERSION="$tag-unstable-$date"
fi
cd - >/dev/null

echo "PiliPalaX: $OLD_REV -> $NEW_REV ($NEW_VERSION)"

# First update version/rev/hash so the source and the lock never diverge.
update-source-version "$UPDATE_NIX_ATTR_PATH" "$NEW_VERSION" --rev="$NEW_REV"

# Refresh the vendored lockfile from the same revision (yq emits duplicate
# JSON keys for these lockfiles, so convert with python/pyyaml instead).
curl -fsSL "https://raw.githubusercontent.com/$REPO/$NEW_REV/pubspec.lock" -o "$TMP/pubspec.lock"
python3 -c "import json,yaml,sys; json.dump(yaml.safe_load(open(sys.argv[1])), open('$DIR/pubspec.lock.json','w'), indent=2); print('', file=open('$DIR/pubspec.lock.json','a'))" "$TMP/pubspec.lock"
