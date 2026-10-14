#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p jq -p gnused -p nix -p python3
# shellcheck shell=bash
set -euo pipefail

# Trae international has no GitHub releases; the only machine-readable version
# source is the launcher API used by the official download button. It returns
# per-region CDN URLs whose path embeds the build version
# (stable/<version>/linux/...). The "va" region (lf-cdn.trae.ai/obj/trae-ai-us)
# is the one the website hands out worldwide, so hashes are prefetched from
# those exact URLs and the result is verified with a real src build, catching
# a URL template in default.nix that drifts away from the API.

FILE="$(dirname "$(readlink -f "$0")")/default.nix"
ATTR="${UPDATE_NIX_ATTR_PATH:-uncategorized-DataEraserC.trae-intl}"

URLS=$(curl -fsSL 'https://api.trae.ai/icube/api/v1/native/version/trae/latest' |
  jq -r '.data.manifest.linux.versions[] | select(.region == "va" and (.arch == "x64.tar.gz" or .arch == "arm64.tar.gz")) | .arch + " " + .url')
URL_X64=$(echo "$URLS" | grep '^x64.tar.gz ' | cut -d' ' -f2)
URL_ARM64=$(echo "$URLS" | grep '^arm64.tar.gz ' | cut -d' ' -f2)
NEW_VERSION=$(echo "$URL_X64" | sed -n 's#.*/stable/\([0-9.]*\)/linux/.*#\1#p')

[ -n "$NEW_VERSION" ] || {
  echo "Failed to detect new version"
  exit 1
}
echo "detected version: $NEW_VERSION"

OLD_VERSION=$(sed -n 's/^  version = "\([^"]*\)";/\1/p' "$FILE")
if [ "$NEW_VERSION" = "$OLD_VERSION" ] && [ "$NEW_VERSION" = "${UPDATE_NIX_OLD_VERSION:-$NEW_VERSION}" ]; then
  echo "trae-intl already at $NEW_VERSION"
  exit 0
fi

python3 - "$FILE" "$NEW_VERSION" "$URL_X64" "$URL_ARM64" <<'PYEOF'
import json
import re
import subprocess
import sys

path, new_ver, url_x64, url_arm64 = sys.argv[1:]
content = open(path).read()

for url in (url_x64, url_arm64):
    h = subprocess.run(['nix', 'store', 'prefetch-file', '--json', url],
                       capture_output=True, text=True, check=True)
    arch = 'x86_64-linux' if 'x64' in url.rsplit('/', 1)[-1] else 'aarch64-linux'
    new_hash = json.loads(h.stdout)['hash']
    content, n = re.subn(rf'{arch} = "sha256-[^"]+"', f'{arch} = "{new_hash}"', content)
    assert n == 1, f'{arch} hash line not found'

content, n = re.subn(r'version = "[^"]+"', f'version = "{new_ver}"', content, count=1)
assert n == 1, 'version line not found'

open(path, 'w').write(content)
print(f'trae-intl updated to {new_ver}')
PYEOF

nix build --no-link ".#$ATTR.src"
