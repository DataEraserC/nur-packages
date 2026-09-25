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

NEW_VERSION=$(nix eval --raw ".#$FLAT_PATH.version")

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$SRC_AFTER" "$TMPDIR/source"
chmod -R +w "$TMPDIR/source"
cd "$TMPDIR/source" || exit 1

# Upstream cuts the release tag before bumping package.json, so the tag's
# version field lags one release behind. Mirror the derivation's postPatch
# so the regenerated lockfile records the same version the build installs.
sed -i "s|\"version\": \"[^\"]*\"|\"version\": \"$NEW_VERSION\"|" package.json

# Seed the committed lockfile so semver ranges only move when upstream
# actually changes them, instead of floating on every run.
cp "$SCRIPT_DIR/package-lock.json" package-lock.json

npm install --package-lock-only --ignore-scripts --no-audit --no-fund

cp package-lock.json "$SCRIPT_DIR/package-lock.json"
NEW_HASH=$(prefetch-npm-deps "$SCRIPT_DIR/package-lock.json")
sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$NEW_HASH\";|" "$SCRIPT_DIR/default.nix"
