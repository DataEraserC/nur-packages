#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p jq -p nix-update
# shellcheck shell=bash
set -euo pipefail

NEW_VERSION=$(curl -fsSL 'https://api.github.com/repos/lollipopkit/flutter_server_box/releases/latest' | jq -r .tag_name | sed 's/^v//')
[ -n "$NEW_VERSION" ] && [ "$NEW_VERSION" != "null" ] || {
  echo "Failed to detect new version" >&2
  exit 1
}
exec nix-update "$UPDATE_NIX_ATTR_PATH" --version "$NEW_VERSION"
