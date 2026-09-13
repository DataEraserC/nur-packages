#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p nodejs -p prefetch-npm-deps -p nix-update
# shellcheck shell=bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

nix-update "$UPDATE_NIX_ATTR_PATH" --src-only

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$(nix build --no-link --print-out-paths ".#$UPDATE_NIX_ATTR_PATH.src")" "$TMPDIR/source"
chmod -R +w "$TMPDIR/source"
cd "$TMPDIR/source" || exit 1

npm install --ignore-scripts --no-audit --no-fund

cp package-lock.json "$SCRIPT_DIR/package-lock.json"
NEW_HASH=$(prefetch-npm-deps "$SCRIPT_DIR/package-lock.json")
sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$NEW_HASH\";|" "$SCRIPT_DIR/default.nix"
