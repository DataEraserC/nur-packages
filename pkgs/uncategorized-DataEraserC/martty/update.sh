#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash nodejs_24 prefetch-npm-deps nix-update
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
NEW_VERSION=$(npm view martty version --registry=https://registry.npmjs.org)

if [ "$NEW_VERSION" = "$UPDATE_NIX_OLD_VERSION" ]; then
	exit 0
fi

nix-update "$UPDATE_NIX_ATTR_PATH" --version "$NEW_VERSION" --src-only

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
SRC=$(nix eval --raw ".#${UPDATE_NIX_ATTR_PATH}.src")
mkdir "$TMPDIR/source"
tar -xzf "$SRC" -C "$TMPDIR/source" --strip-components=1
cd "$TMPDIR/source"
npm install --ignore-scripts --registry=https://registry.npmjs.org
cp package-lock.json "$SCRIPT_DIR/package-lock.json"

NEW_HASH=$(prefetch-npm-deps "$SCRIPT_DIR/package-lock.json")
sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$NEW_HASH\";|" "$SCRIPT_DIR/default.nix"

cd "$SCRIPT_DIR/../../.."
nix build ".#${UPDATE_NIX_ATTR_PATH}"
