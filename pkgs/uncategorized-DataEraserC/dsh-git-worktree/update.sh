#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p nodejs_24 -p prefetch-npm-deps -p nix-update
# shellcheck shell=bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

SRC_BEFORE=$(nix build --no-link --print-out-paths ".#$UPDATE_NIX_ATTR_PATH.src")

nix-update "$UPDATE_NIX_ATTR_PATH" --src-only

SRC_AFTER=$(nix build --no-link --print-out-paths ".#$UPDATE_NIX_ATTR_PATH.src")

if [ "$SRC_BEFORE" = "$SRC_AFTER" ]; then
  exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$SRC_AFTER" "$TMPDIR/source"
chmod -R +w "$TMPDIR/source"
cd "$TMPDIR/source" || exit 1

cp "$SCRIPT_DIR/package-lock.json" package-lock.json

npm install --legacy-peer-deps --ignore-scripts --no-audit --no-fund

cp package.json "$SCRIPT_DIR/package.json"
cp package-lock.json "$SCRIPT_DIR/package-lock.json"
NEW_HASH=$(prefetch-npm-deps "$SCRIPT_DIR/package-lock.json")
sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$NEW_HASH\";|" "$SCRIPT_DIR/default.nix"
