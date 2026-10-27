#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git -p curl -p nix -p python3 -p python3Packages.pyyaml -p common-updater-scripts
# shellcheck shell=bash
set -euo pipefail

DIR=$(dirname "$(readlink -f "$0")")
FILE="$DIR/default.nix"
REPO="TG-Twilight/c001apk"

OLD_VERSION=$(sed -n 's/^[[:space:]]*version = "\(.*\)";/\1/p' "$FILE")
NEW_TAG=$(git ls-remote --tags --refs "https://github.com/$REPO" |
  sed -n 's#.*refs/tags/\([0-9.]*\)-release$#\1#p' | sort -V | tail -1)
[ -n "$NEW_TAG" ] || {
  echo "Failed to query tags of $REPO" >&2
  exit 1
}
[ "$NEW_TAG" != "$OLD_VERSION" ] || {
  echo "$REPO already at $NEW_TAG"
  exit 0
}

echo "$REPO: $OLD_VERSION -> $NEW_TAG"
update-source-version "$UPDATE_NIX_ATTR_PATH" "$NEW_TAG"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "https://raw.githubusercontent.com/$REPO/$NEW_TAG-release/apps/flutter/pubspec.lock" \
  -o "$TMP/pubspec.lock"
python3 - "$TMP/pubspec.lock" "$DIR/pubspec.lock.json" <<'PY'
import json
import sys
import yaml

src, dst = sys.argv[1], sys.argv[2]
with open(src) as handle:
    data = yaml.safe_load(handle)
with open(dst, "w") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
