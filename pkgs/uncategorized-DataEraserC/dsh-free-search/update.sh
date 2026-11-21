#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p coreutils -p curl -p gnused -p jq -p nix-update -p pnpm_11
# shellcheck shell=bash
set -euo pipefail

# Agent2API-style generative lockfile update for dsh-free-search.
#
# Upstream ships a pnpm-lock.yaml that regularly predates its own package.json
# (e.g. v0.9.78 added react-test-renderer without refreshing the lock), so the
# offline pnpm install rejects it with ERR_PNPM_OUTDATED_LOCKFILE. This script
# owns the whole cycle: bump version + src, regenerate the checked-in lock
# with the pinned pnpm, and recompute pnpmDepsHash.

DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$DIR/../../..")
ATTR=${UPDATE_NIX_ATTR_PATH:-uncategorized-DataEraserC.dsh-free-search}
# The flake output flattens package groups, so nix build uses the bare name.
FLAT=${ATTR##*.}

die() {
  printf 'dsh-free-search: %s\n' "$*" >&2
  exit 1
}

cd "$ROOT"

# 1) Move to the latest upstream tag and refresh the src hash (no-op when
#    already current).
nix-update "$FLAT" --flake --src-only

# 2) Regenerate the lockfile from the source that will actually be built.
SRC=$(nix build --no-link --print-out-paths ".#$FLAT.src")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -a "$SRC/." "$TMP/src"
chmod -R u+w "$TMP/src"
cd "$TMP/src"
# Seed from the committed lock so unchanged ranges do not drift.
cp "$DIR/pnpm-lock.yaml" pnpm-lock.yaml
pnpm install --lockfile-only --ignore-scripts
cp pnpm-lock.yaml "$DIR/pnpm-lock.yaml"

# 3) Recompute pnpmDepsHash: an empty hash makes the FOD fail with `got:`.
cd "$ROOT"
sed -i 's|pnpmDepsHash = "sha256-[^"]*";|pnpmDepsHash = "";|' "$DIR/default.nix"
set +e
OUT=$(nix build --no-link ".#$FLAT.pnpmDeps" 2>&1)
set -e
GOT=$(printf '%s\n' "$OUT" | sed -n 's/.*got: *\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | head -1)
[ -n "$GOT" ] || {
  printf '%s\n' "$OUT" >&2
  die "could not read the pnpmDeps hash"
}
sed -i "s|pnpmDepsHash = \"\";|pnpmDepsHash = \"$GOT\";|" "$DIR/default.nix"
nix build --no-link ".#$FLAT.pnpmDeps"

echo "dsh-free-search: $(nix eval --raw ".#$FLAT.version") ready"
