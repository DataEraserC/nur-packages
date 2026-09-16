#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p nodejs_24 -p prefetch-npm-deps -p nix-update
# shellcheck shell=bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

SRC_BEFORE=$(nix build --no-link --print-out-paths ".#$UPDATE_NIX_ATTR_PATH.src")

nix-update "$UPDATE_NIX_ATTR_PATH" --src-only

SRC_AFTER=$(nix build --no-link --print-out-paths ".#$UPDATE_NIX_ATTR_PATH.src")

# The lockfile only depends on the source tree, so an unchanged source means an
# unchanged lockfile. Regenerating it anyway would let semver ranges float and
# rewrite npmDepsHash on every run, invalidating the binary cache for nothing.
if [ "$SRC_BEFORE" = "$SRC_AFTER" ]; then
  exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$SRC_AFTER" "$TMPDIR/source"
chmod -R +w "$TMPDIR/source"
cd "$TMPDIR/source" || exit 1

# Seeding the committed lockfile keeps every already locked version, so npm only
# adds or removes what the new package.json actually requires.
cp "$SCRIPT_DIR/package-lock.json" package-lock.json

npm install --ignore-scripts --no-audit --no-fund

cp package-lock.json "$SCRIPT_DIR/package-lock.json"
NEW_HASH=$(prefetch-npm-deps "$SCRIPT_DIR/package-lock.json")
sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$NEW_HASH\";|" "$SCRIPT_DIR/default.nix"
