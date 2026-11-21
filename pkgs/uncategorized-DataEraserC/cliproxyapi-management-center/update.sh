#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p nodejs_24 -p prefetch-npm-deps -p nix-update
# shellcheck shell=bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$SCRIPT_DIR/../../..")

# Upstream publishes source only: no tag carries a package-lock.json, so the
# lockfile committed here is generated below and is tied to the version.
deps_ok() {
  nix build --no-link ".#$UPDATE_NIX_ATTR_PATH.npmDeps" >/dev/null 2>&1
}

SRC_BEFORE=$(cd "$ROOT" && nix build --no-link --print-out-paths ".#$UPDATE_NIX_ATTR_PATH.src")

(cd "$ROOT" && nix-update "$UPDATE_NIX_ATTR_PATH" --src-only)

SRC_AFTER=$(cd "$ROOT" && nix build --no-link --print-out-paths ".#$UPDATE_NIX_ATTR_PATH.src")

# An unchanged source means an unchanged lockfile, but only when the dependency
# cache that lockfile feeds still builds: a run interrupted after nix-update
# leaves a new version with the previous lock, and comparing sources alone calls
# that finished.
if [ "$SRC_BEFORE" = "$SRC_AFTER" ] && (cd "$ROOT" && deps_ok); then
  exit 0
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp -r "$SRC_AFTER" "$TMPDIR/source"
chmod -R +w "$TMPDIR/source"
cd "$TMPDIR/source"

# npm resolves the new package.json from scratch. Seeding the committed lockfile
# instead mixes locked subtrees with ranges the new release no longer allows
# (typescript-eslint 8.70.0 against a ^8.72.0 requirement) and npm stops with
# ERESOLVE.
npm install --ignore-scripts --no-audit --no-fund

cp package-lock.json "$SCRIPT_DIR/package-lock.json"
NEW_HASH=$(prefetch-npm-deps "$SCRIPT_DIR/package-lock.json")
sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$NEW_HASH\";|" "$SCRIPT_DIR/default.nix"

(cd "$ROOT" && nix build --no-link ".#$UPDATE_NIX_ATTR_PATH.npmDeps")
