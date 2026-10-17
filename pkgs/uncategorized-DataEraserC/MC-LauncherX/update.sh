#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p jq -p nix -p python3
# shellcheck shell=bash
set -euo pipefail

FILE="$(dirname "$(readlink -f "$0")")/MC-LauncherX.nix"
export FILE
MCX_JSON=$(mktemp)
trap 'rm -f "$MCX_JSON"' EXIT
curl -fsSL 'https://api.corona.studio/Build/get/latest/all/stable' -o "$MCX_JSON"
python3 - "$MCX_JSON" <<'PYEOF'
import json
import os
import re
import subprocess
import sys

# Newest first: the endpoint lists one item per platform but ordering is not
# part of its contract, and releases may repeat a platform (net9.0 -> net10.0
# refresh kept only the newest build per runtime on the stable channel).
items = sorted(
    json.load(open(sys.argv[1])),
    key=lambda i: i.get("releaseDate", ""),
    reverse=True,
)
path = os.environ["FILE"]
text = open(path).read()
# Match on runtime only: upstream migrates the framework (net9.0 -> net10.0)
# without dropping a platform, and hardcoding the framework made this updater
# report "already up to date" while every pinned zip had been purged (HTTP 404).
targets = {
    "x86_64-linux": "linux-x64",
    "aarch64-linux": "linux-arm64",
    "x86_64-darwin": "osx-x64",
    "aarch64-darwin": "osx-arm64",
}
changed = False
for plat, rt in targets.items():
    hit = next(
        (i for i in items if i.get("runtime") == rt and i.get("isPublished", True)),
        None,
    )
    if hit is None:
        print(f"MC-LauncherX {plat}: no published stable build for {rt}; keeping current pin")
        continue
    fw, hid = hit["framework"], hit["id"]
    new_ver = f"{hid}/{fw}.{rt}"
    new_url = f"https://api.corona.studio/Build/get/{hid}/{fw}.{rt}.zip"
    m = re.search(rf'^\s*{plat} = "([^"]+)";', text, re.M)
    if not m:
        print(f"MC-LauncherX {plat}: version entry not found in {path}", file=sys.stderr)
        sys.exit(1)
    old = m.group(1)
    if old == new_ver:
        continue
    old_id, old_tail = old.split("/", 1)
    old_url = f"https://api.corona.studio/Build/get/{old_id}/{old_tail}.zip"
    if f'{plat} = "{old}";' not in text or old_url not in text:
        print(f"MC-LauncherX {plat}: old pin not found for {old}", file=sys.stderr)
        sys.exit(1)
    text = text.replace(f'{plat} = "{old}";', f'{plat} = "{new_ver}";')
    text = text.replace(old_url, new_url)
    out = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", new_url],
        capture_output=True,
        text=True,
    )
    if out.returncode != 0:
        print(
            f"MC-LauncherX {plat}: prefetch failed for {new_url}:\n{out.stderr[-800:]}",
            file=sys.stderr,
        )
        sys.exit(1)
    h = json.loads(out.stdout)["hash"]
    lines = text.split("\n")
    for i, ln in enumerate(lines):
        if f'url = "{new_url}";' in ln:
            for j in range(i + 1, min(i + 5, len(lines))):
                hm = re.match(r'^(\s*)hash = "sha256-[^"]+"', lines[j])
                if hm:
                    lines[j] = f'{hm.group(1)}hash = "{h}";'
                    break
            else:
                print(f"MC-LauncherX {plat}: hash line not found after {new_url}", file=sys.stderr)
                sys.exit(1)
            break
    else:
        print(f"MC-LauncherX {plat}: url line not found after rewrite", file=sys.stderr)
        sys.exit(1)
    text = "\n".join(lines)
    changed = True
    print(f"MC-LauncherX {plat}: {old} -> {new_ver}")

if changed:
    open(path, "w").write(text)
else:
    print("MC-LauncherX already up to date")
PYEOF

echo "Build test: nix build .#MC-LauncherX"
nix build --no-link .#MC-LauncherX
echo "MC-LauncherX update OK"
