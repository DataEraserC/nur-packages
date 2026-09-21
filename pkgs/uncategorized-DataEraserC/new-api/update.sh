#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p nix-update -p curl
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

echo "Updating new-api..."

# Detect latest release tag from atom feed
LATEST_TAG=$(curl -fsSL "https://github.com/QuantumNous/new-api/releases.atom" \
  | grep -oP '(?<=<id>tag:github.com,2008:Repository/[0-9]+/)v[0-9][^<]+' \
  | head -1) || true

if [ -z "$LATEST_TAG" ]; then
  LATEST_TAG=$(git ls-remote --tags https://github.com/QuantumNous/new-api \
    | sed -n 's#.*refs/tags/v\([0-9].*\)$#v\1#p' \
    | grep -v '\^{}' \
    | sort -V | tail -1)
fi

NEW_VERSION="${LATEST_TAG#v}"
OLD_VERSION="${UPDATE_NIX_OLD_VERSION:-}"

echo "Latest upstream tag: $LATEST_TAG (version: $NEW_VERSION)"
echo "Current version:     $OLD_VERSION"

if [ "$NEW_VERSION" = "$OLD_VERSION" ]; then
  echo "Already up to date."
  exit 0
fi

# Step 1: nix-update handles version, src hash, and vendorHash
echo "Updating to $NEW_VERSION..."
nix-update "$UPDATE_NIX_ATTR_PATH" --version "$NEW_VERSION"

# Step 2: Regenerate webDeps FOD hash.
# Replace the current outputHash with lib.fakeHash, build, extract the real hash.
sed -i 's|outputHash = "sha256-[^"]*"|outputHash = lib.fakeHash|' "$SCRIPT_DIR/default.nix"

WEB_DEPS_HASH=$(nix build ".#${UPDATE_NIX_ATTR_PATH}" --no-link 2>&1 \
  | grep -oP 'got:\s+sha256-[A-Za-z0-9/+=]+' | head -1 | sed 's/got:\s*//') || true

if [ -n "$WEB_DEPS_HASH" ]; then
  sed -i "s|outputHash = lib.fakeHash;|outputHash = \"$WEB_DEPS_HASH\";|" "$SCRIPT_DIR/default.nix"
  echo "webDeps hash updated: $WEB_DEPS_HASH"
else
  echo "ERROR: Could not determine webDeps hash."
  echo "Run: nix build .#${UPDATE_NIX_ATTR_PATH} 2>&1 | grep 'got:'"
  exit 1
fi

echo "Done! Version: $NEW_VERSION"
