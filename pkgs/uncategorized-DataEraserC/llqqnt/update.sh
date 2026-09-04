#!/usr/bin/env nix-shell
#!nix-shell -i bash -p git -p jq -p nix
# shellcheck shell=bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO="LiteLoaderQQNT/LiteLoaderQQNT"
OLD_REV=$(sed -n 's/^  LiteLoaderQQNTVersion = "\(.*\)";/\1/p' "$SCRIPT_DIR/llqqnt.nix")
NEW_REV=$(git ls-remote "https://github.com/$REPO.git" HEAD | cut -f1)

if [ -z "$NEW_REV" ]; then
  echo "Failed to query latest revision of $REPO" >&2
  exit 1
fi

if [ "$NEW_REV" = "$OLD_REV" ]; then
  echo "llqqnt: LiteLoaderQQNT already at $NEW_REV"
  exit 0
fi

NEW_HASH=$(nix store prefetch-file --json --unpack "https://github.com/$REPO/archive/$NEW_REV.tar.gz" | jq -r .hash)
sed -i "s|^  LiteLoaderQQNTVersion = \".*\";|  LiteLoaderQQNTVersion = \"$NEW_REV\";|" "$SCRIPT_DIR/llqqnt.nix"
sed -i "s|^    rev = \".*\";|    rev = \"$NEW_REV\";|" "$SCRIPT_DIR/llqqnt.nix"
sed -i "s|^    hash = \"sha256-[^\"]*\";|    hash = \"$NEW_HASH\";|" "$SCRIPT_DIR/llqqnt.nix"
echo "llqqnt: updated LiteLoaderQQNT $OLD_REV -> $NEW_REV"
