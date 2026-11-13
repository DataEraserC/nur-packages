#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p gnused -p nix -p python3
# shellcheck shell=bash
set -euo pipefail

# The download page is rendered client-side, but the "download" button target
# redirects to the CDN URL of the latest build for that platform, and that URL
# embeds the version. Using the redirect avoids scraping a JS bundle.
FILE="$(dirname "$(readlink -f "$0")")/default.nix"
ATTR="${UPDATE_NIX_ATTR_PATH:-xiaohuanxiong}"

latest_url() {
  curl -fsSI "https://xiaohuanxiong.com/download/catalog?platform=$1" |
    tr -d '\r' |
    sed -n 's/^[Ll]ocation: //p'
}

URL_X64="$(latest_url linux-x64)"
URL_ARM64="$(latest_url linux-arm64)"
NEW_VERSION="$(printf '%s' "$URL_X64" | sed -n 's#.*-\([0-9][0-9.]*\)-amd64\.deb$#\1#p')"

[ -n "$NEW_VERSION" ] || {
  echo "Failed to detect new version"
  exit 1
}
echo "detected version: $NEW_VERSION"

OLD_VERSION=$(sed -n 's/^  version = "\([^"]*\)";/\1/p' "$FILE")
if [ "$NEW_VERSION" = "$OLD_VERSION" ]; then
  echo "xiaohuanxiong already at $NEW_VERSION"
  exit 0
fi

python3 - "$FILE" "$NEW_VERSION" "$URL_X64" "$URL_ARM64" <<'PYEOF'
import json
import re
import subprocess
import sys

path, new_ver, url_x64, url_arm64 = sys.argv[1:]
content = open(path).read()

for url, arch, name in (
    (url_x64, "x86_64-linux", f"xiaohuanxiong-{new_ver}-amd64.deb"),
    (url_arm64, "aarch64-linux", f"xiaohuanxiong-{new_ver}-arm64.deb"),
):
    # The CDN file name is CJK, which Nix rejects as a store path name.
    h = subprocess.run(
        ["nix", "store", "prefetch-file", "--name", name, "--json", url],
        capture_output=True, text=True, check=True,
    )
    new_hash = json.loads(h.stdout)["hash"]
    content, n = re.subn(rf'{arch} = "sha256-[^"]+"', f'{arch} = "{new_hash}"', content)
    assert n == 1, f"{arch} hash line not found"

content, n = re.subn(r'version = "[^"]+"', f'version = "{new_ver}"', content, count=1)
assert n == 1, "version line not found"

open(path, "w").write(content)
print(f"xiaohuanxiong updated to {new_ver}")
PYEOF

nix build --no-link ".#${ATTR}.src"
