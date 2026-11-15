#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p jq -p nix-update
# shellcheck shell=bash
set -euo pipefail

# shellcheck source=../../../tools/github-api.sh
source "$(dirname "$(readlink -f "$0")")/../../../tools/github-api.sh"

NEW_VERSION="$(
  gh_release_assets DataEraserC/nur-packages aDrive |
    grep -oP 'aDrive-\K[0-9][0-9.]*(?=\.exe)' |
    sort -V |
    tail -n1 || true
)"
[ -n "$NEW_VERSION" ] || {
  echo "Failed to detect new version" >&2
  exit 1
}
exec nix-update "$UPDATE_NIX_ATTR_PATH" --version "$NEW_VERSION"
