#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p nodejs_24 -p prefetch-npm-deps -p nix-update
# shellcheck shell=bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# This package lives in a flat group (uncategorized-DataEraserC) and needs
# flake inputs (deepseek-harness), so we must use --flake. However the
# flake's packages output flattens groups, exposing only the bare name.
# helpers/update.nix passes the dotted path through UPDATE_NIX_ATTR_PATH,
# so strip the group prefix here.
FLAT_PATH="${UPDATE_NIX_ATTR_PATH##*.}"

SRC_BEFORE=$(nix build --no-link --print-out-paths ".#$FLAT_PATH.src")

nix-update "$FLAT_PATH" --src-only --flake

SRC_AFTER=$(nix build --no-link --print-out-paths ".#$FLAT_PATH.src")

if [ "$SRC_BEFORE" = "$SRC_AFTER" ]; then
  exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if [ -d "$SRC_AFTER" ]; then
  cp -r "$SRC_AFTER" "$TMPDIR/source"
else
  mkdir -p "$TMPDIR/source"
  tar -xf "$SRC_AFTER" -C "$TMPDIR/source" --strip-components=1
fi
chmod -R +w "$TMPDIR/source"
cd "$TMPDIR/source" || exit 1

cp "$SCRIPT_DIR/package-lock.json" package-lock.json

npm install --ignore-scripts --no-audit --no-fund

cp package-lock.json "$SCRIPT_DIR/package-lock.json"
NEW_HASH=$(prefetch-npm-deps "$SCRIPT_DIR/package-lock.json")
sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$NEW_HASH\";|" "$SCRIPT_DIR/default.nix"
