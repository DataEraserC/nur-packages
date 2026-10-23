#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p jq -p gnused -p nix -p python3
set -euo pipefail

FILE="$(dirname "$(readlink -f "$0")")/default.nix"

NEW_VERSION=$(curl -fsSL 'https://zcode.z.ai/cn/docs/install' |
  sed -n 's#.*/releases/\([0-9.]*\)/linux-x64/ZCode-[0-9.]*-linux-x64\.AppImage.*#\1#p' | head -1)

[ -n "$NEW_VERSION" ] || { echo "Failed to detect new version"; exit 1; }
echo "detected version: $NEW_VERSION"

OLD_VERSION=$(sed -n 's/^  version = "\([^"]*\)";/\1/p' "$FILE")
if [ "$NEW_VERSION" = "$OLD_VERSION" ]; then
  echo "zcode-cn already at $NEW_VERSION"
  exit 0
fi

python3 - "$FILE" "$NEW_VERSION" <<'PYEOF'
import json
import re
import subprocess
import sys

path, new_ver = sys.argv[1:]
content = open(path).read()

for plat, arch in (("x64", "x86_64-linux"), ("arm64", "aarch64-linux")):
    url = f"https://cdn-zcode.z.ai/zcode/electron/releases/{new_ver}/linux-{plat}/ZCode-{new_ver}-linux-{plat}.AppImage"
    h = subprocess.run(['nix', 'store', 'prefetch-file', '--json', url],
                       capture_output=True, text=True, check=True)
    new_hash = json.loads(h.stdout)['hash']
    content, n = re.subn(rf'{arch} = "sha256-[^"]+"', f'{arch} = "{new_hash}"', content)
    assert n == 1, f'{arch} hash line not found'

content, n = re.subn(r'version = "[^"]+"', f'version = "{new_ver}"', content, count=1)
assert n == 1, 'version line not found'

open(path, 'w').write(content)
print(f'zcode-cn updated to {new_ver}')
PYEOF

nix build --no-link ".#uncategorized-DataEraserC.zcode-cn.src"
