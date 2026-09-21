#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p nix-update
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

echo "Updating new-api..."

# nix-update --version branch tracks the latest release from the atom feed,
# updates version, src hash, and vendorHash in one pass.
nix-update "$UPDATE_NIX_ATTR_PATH" --version branch

# webDeps FOD hash may have changed if bun.lock changed upstream.
# Set a fake hash, rebuild to get the real one.
sed -i 's|outputHash = "sha256-[^"]*"|outputHash = lib.fakeHash|' "$SCRIPT_DIR/default.nix"

WEB_DEPS_HASH=$(nix build ".#${UPDATE_NIX_ATTR_PATH}.webDeps" --no-link 2>&1 \
  | grep -oP 'got:\s+sha256-[A-Za-z0-9/+=]+' | head -1 | sed 's/got:\s*//') || true

if [ -n "$WEB_DEPS_HASH" ]; then
  sed -i "s|outputHash = lib.fakeHash;|outputHash = \"$WEB_DEPS_HASH\";|" "$SCRIPT_DIR/default.nix"
  echo "webDeps hash updated: $WEB_DEPS_HASH"
else
  sed -i 's|outputHash = lib.fakeHash;|outputHash = "sha256-AAAA";|' "$SCRIPT_DIR/default.nix"
  echo "WARNING: Could not determine webDeps hash. Build manually and update."
fi

echo "Done!"
