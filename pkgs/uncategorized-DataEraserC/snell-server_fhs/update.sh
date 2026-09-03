#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p nix -p python3
# shellcheck shell=bash
set -euo pipefail

FILE="$(find "$(dirname "$(readlink -f "$0")")" -maxdepth 1 -name '*.nix' ! -name 'default.nix' | head -n1)"
NEW_VERSION=$(curl -fsSL 'https://kb.nssurge.com/surge-knowledge-base/zh/release-notes/snell' |
  grep -oP 'snell-server-\K[^"/]*(?=-linux-amd64\.zip)' | sort -V | tail -n1)
[ -n "$NEW_VERSION" ] || {
  echo "Failed to detect new version" >&2
  exit 1
}
export NEW_VERSION
python3 - "$FILE" <<'PYEOF'
import json
import os
import re
import subprocess
import sys

path = sys.argv[1]
new = os.environ["NEW_VERSION"]
text = open(path).read()
suffixes = {"x86_64-linux": "amd64", "i686-linux": "i386", "aarch64-linux": "aarch64", "aarch32-linux": "armv7l"}

changed = False
url_hash = {}
for plat, suffix in suffixes.items():
    m = re.search(rf'^\s*{plat} = "([^"]+)";', text, re.M)
    old = m.group(1)
    if old == new:
        continue
    new_url = f"https://dl.nssurge.com/snell/snell-server-{new}-linux-{suffix}.zip"
    out = subprocess.run(["nix", "store", "prefetch-file", "--json", new_url], capture_output=True, text=True)
    if out.returncode != 0:
        print(f"snell {plat}: no release for {new}, keeping {old}")
        continue
    url_hash[new_url] = json.loads(out.stdout)["hash"]
    text = text.replace(f"snell-server-{old}-linux-{suffix}.zip", f"snell-server-{new}-linux-{suffix}.zip")
    text = text.replace(f'{plat} = "{old}";', f'{plat} = "{new}";')
    changed = True
    print(f"snell {plat}: {old} -> {new}")

lines = text.split("\n")
for i, ln in enumerate(lines):
    m = re.search(r'url = "([^"]+)";', ln)
    if not m or m.group(1) not in url_hash:
        continue
    for j in range(i + 1, min(i + 4, len(lines))):
        hm = re.match(r'^(\s*)hash = "sha256-[^"]+"', lines[j])
        if hm:
            lines[j] = f'{hm.group(1)}hash = "{url_hash[m.group(1)]}";'
            break

if changed:
    open(path, "w").write("\n".join(lines))
else:
    print(f"snell already at {new}")
PYEOF
