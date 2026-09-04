#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p jq -p nix-update
# shellcheck shell=bash
set -euo pipefail

NEW_VERSION=$(curl -fsSL 'https://api.github.com/repos/DataEraserC/nur-packages/releases/tags/aDrive' |
  jq -r '.assets[]?.name' |
  grep -oP 'aDrive-\K[0-9][0-9.]*(?=\.exe)' |
  sort -V |
  tail -n1)
[ -n "$NEW_VERSION" ] || {
  echo "Failed to detect new version" >&2
  exit 1
}
exec nix-update "$UPDATE_NIX_ATTR_PATH" --version "$NEW_VERSION"
