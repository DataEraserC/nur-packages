#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p nodejs -p prefetch-npm-deps -p nix-update
# shellcheck shell=bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# This package lives in a flat group (uncategorized-DataEraserC) and needs
# flake inputs (deepseek-harness), so nix-update must run in --flake mode.
# The flake's packages output only exposes the flattened bare name, while
# helpers/update.nix hands us the grouped attrPath, so strip the prefix.
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

# Seed the committed lockfile so unchanged ranges keep their pinned versions,
# then let npm rewrite it against the new package.json (root version, new
# resolutions).
cp "$SCRIPT_DIR/package-lock.json" package-lock.json

npm install --ignore-scripts --no-audit --no-fund

cp package-lock.json "$SCRIPT_DIR/package-lock.json"
NEW_HASH=$(prefetch-npm-deps "$SCRIPT_DIR/package-lock.json")
sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$NEW_HASH\";|" "$SCRIPT_DIR/default.nix"

# Build once so a bad npmDepsHash or a broken new release fails here instead
# of waiting for CI.
nix build --no-link ".#$FLAT_PATH"
