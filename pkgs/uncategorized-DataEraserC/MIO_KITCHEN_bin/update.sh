#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p jq -p nix -p gnused
# shellcheck shell=bash
set -euo pipefail

DIR=$(dirname "$(readlink -f "$0")")
FILE="$DIR/MIO_KITCHEN_bin.nix"
REPO="ColdWindScholar/MIO-KITCHEN-SOURCE"

OLD_TAG=$(sed -n 's/^  releaseTag = "\([^"]*\)";/\1/p' "$FILE")
OLD_VER=$(sed -n 's/^  version = "\([^"]*\)";/\1/p' "$FILE")

JSON=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")
TAG=$(jq -r .tag_name <<<"$JSON")
ASSET=$(jq -r '.assets[].name | select(test("^MIO-KITCHEN-.*-linux\\.zip$"))' <<<"$JSON" | head -n1)
[ -n "$TAG" ] && [ "$TAG" != "null" ] || {
  echo "Failed to detect latest release" >&2
  exit 1
}
VER=${ASSET#MIO-KITCHEN-}
VER=${VER%-linux.zip}

if [ "$TAG" = "$OLD_TAG" ] && [ "$VER" = "$OLD_VER" ]; then
  echo "MIO_KITCHEN already at $OLD_VER ($OLD_TAG)"
  exit 0
fi

URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"
HASH=$(nix store prefetch-file --json "$URL" | jq -r .hash)

sed -i "s|^  releaseTag = \"[^\"]*\";|  releaseTag = \"$TAG\";|" "$FILE"
sed -i "s|^  version = \"[^\"]*\";|  version = \"$VER\";|" "$FILE"
sed -i "s|^    hash = \"sha256-[^\"]*\";|    hash = \"$HASH\";|" "$FILE"
echo "MIO_KITCHEN updated: $OLD_VER ($OLD_TAG) -> $VER ($TAG)"
