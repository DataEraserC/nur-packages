#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p jq -p nix-update
# shellcheck shell=bash
set -euo pipefail

# shellcheck source=../../../tools/github-api.sh
source "$(dirname "$(readlink -f "$0")")/../../../tools/github-api.sh"

NEW_VERSION="$(gh_latest_tag msojocs/wechat-web-devtools-linux | sed 's/^v//' || true)"
[ -n "$NEW_VERSION" ] && [ "$NEW_VERSION" != "null" ] || {
  echo "Failed to detect new version" >&2
  exit 1
}
exec nix-update "$UPDATE_NIX_ATTR_PATH" --version "$NEW_VERSION"
