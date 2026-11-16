#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p jq -p nix-update
# shellcheck shell=bash
set -euo pipefail

# shellcheck source=../../../tools/github-api.sh
source "$(dirname "$(readlink -f "$0")")/../../../tools/github-api.sh"

# gh_api authenticates with GITHUB_TOKEN and falls back to the web endpoints
# when the shared runner's REST quota is exhausted (a bare curl gets 403).
NEW_VERSION=$(gh_api 'repos/wuhgit/CustomPinyinDictionary/releases/latest' |
  jq -r '.assets[]?.name' |
  grep -oP 'CustomPinyinDictionary_Fcitx_Magisk_\K[0-9]{8}(?=\.zip)' |
  head -n1 || true)
[ -n "$NEW_VERSION" ] || {
  echo "Failed to detect new version" >&2
  exit 1
}
exec nix-update "$UPDATE_NIX_ATTR_PATH" --version "$NEW_VERSION"
