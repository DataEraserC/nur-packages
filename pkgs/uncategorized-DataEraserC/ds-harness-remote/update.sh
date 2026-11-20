#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p jq -p nodejs_24 -p prefetch-npm-deps -p nix-update
# shellcheck shell=bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# Flat group (uncategorized-DataEraserC) + flake input (deepseek-harness):
# --flake with the bare attribute name, same as the sibling dsh bundles.
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

# The published tarball keeps its pnpm-workspace devDependencies, including
# workspace:* refs that npm cannot resolve outside the monorepo.
jq 'del(.devDependencies)' package.json >package.json.tmp
mv package.json.tmp package.json

# Seed from the committed lockfile so unchanged transitive ranges do not drift.
cp "$SCRIPT_DIR/package-lock.json" package-lock.json

npm install --legacy-peer-deps --ignore-scripts --no-audit --no-fund

cp package.json "$SCRIPT_DIR/package.json"
cp package-lock.json "$SCRIPT_DIR/package-lock.json"
NEW_HASH=$(prefetch-npm-deps "$SCRIPT_DIR/package-lock.json")
sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$NEW_HASH\";|" "$SCRIPT_DIR/default.nix"
