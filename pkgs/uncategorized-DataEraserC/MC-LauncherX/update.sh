#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p jq -p nix -p python3
# shellcheck shell=bash
set -euo pipefail

FILE="$(dirname "$(readlink -f "$0")")/MC-LauncherX.nix"
export FILE
curl -fsSL 'https://api.corona.studio/Build/get/latest/all/stable' -o /tmp/mcx.json
python3 - /tmp/mcx.json <<'PYEOF'
import json
import os
import re
import subprocess
import sys

items = json.load(open(sys.argv[1]))
path = os.environ["FILE"]
text = open(path).read()
targets = {
    "x86_64-linux": ("net9.0-linux", "linux-x64"),
    "aarch64-linux": ("net9.0-linux", "linux-arm64"),
    "x86_64-darwin": ("net9.0-osx", "osx-x64"),
    "aarch64-darwin": ("net9.0-osx", "osx-arm64"),
}
changed = False
for plat, (fw, rt) in targets.items():
    hit = next((i for i in items if i.get("framework") == fw and i.get("runtime") == rt), None)
    if not hit:
        continue
    new_ver = f"{hit['id']}/{fw}.{rt}"
    new_url = f"https://api.corona.studio/Build/get/{hit['id']}/{fw}.{rt}.zip"
    m = re.search(rf'^\s*{plat} = "([^"]+)";', text, re.M)
    old = m.group(1)
    if old == new_ver:
        continue
    text = text.replace(f'{plat} = "{old}";', f'{plat} = "{new_ver}";')
    text = text.replace(f"https://api.corona.studio/Build/get/{old.split('/')[0]}/{old.split('/',1)[1]}.zip", new_url)
    out = subprocess.run(["nix", "store", "prefetch-file", "--json", new_url], capture_output=True, text=True, check=True)
    h = json.loads(out.stdout)["hash"]
    lines = text.split("\n")
    for i, ln in enumerate(lines):
        um = re.search(r'url = "([^"]+)";', ln)
        if um and um.group(1) == new_url:
            for j in range(i + 1, min(i + 4, len(lines))):
                hm = re.match(r'^(\s*)hash = "sha256-[^"]+"', lines[j])
                if hm:
                    lines[j] = f'{hm.group(1)}hash = "{h}";'
                    break
    text = "\n".join(lines)
    changed = True
    print(f"MC-LauncherX {plat}: {old} -> {new_ver}")

if changed:
    open(path, "w").write(text)
else:
    print("MC-LauncherX already up to date")
PYEOF
