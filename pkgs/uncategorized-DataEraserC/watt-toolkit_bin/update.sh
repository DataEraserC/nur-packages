#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p jq -p nix -p python3
# shellcheck shell=bash
set -euo pipefail

FILE="$(dirname "$(readlink -f "$0")")/watt-toolkit_bin.nix"
python3 - "$FILE" <<'PYEOF'
import json
import re
import subprocess
import sys

path = sys.argv[1]
repo = "BeyondDimension/SteamTools"
releases = json.loads(
    subprocess.run(
        ["curl", "-fsSL", f"https://api.github.com/repos/{repo}/releases?per_page=100"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
)

assets = {}
for rel in releases:
    names = {a["name"] for a in rel.get("assets", [])}
    if names:
        assets[rel["tag_name"]] = names

def has(rel, suffix):
    return any(n.endswith(suffix) for n in assets.get(rel, ()))

x64_candidates = [t for t in assets if has(t, "_linux_x64.tgz") and has(t, "_macos.dmg")]
stable = [t for t in x64_candidates if "-" not in t]
arm_candidates = [t for t in assets if has(t, "_linux_arm64.tgz")]
new_x64 = (stable or x64_candidates)[0]
new_arm = arm_candidates[0]

text = open(path).read()

def pick(new_ver, kind):
    # pick matching current version line to rewrite
    return new_ver

m = re.search(r"version =\s*\{\n(.*?)\n  \};", text, re.S)
body = m.group(1)
# update version map: first line x86_64-linux, second aarch64-linux, third x86_64-darwin
lines = body.split("\n")
ver_by = {}
for ln in lines:
    mm = re.match(r'\s*(x86_64-linux|aarch64-linux|x86_64-darwin) = "([^"]+)"', ln)
    if mm:
        ver_by[mm.group(1)] = mm.group(2)

changed = {}
new_ver_of = {"x86_64-linux": new_x64, "x86_64-darwin": new_x64, "aarch64-linux": new_arm}
for plat, old in ver_by.items():
    new = new_ver_of[plat]
    if old != new:
        # update url: replace download/<old>/ with download/<new>/
        text = text.replace(f"/download/{old}/", f"/download/{new}/")
        # update version map entry
        text = text.replace(f"{plat} = \"{old}\";", f"{plat} = \"{new}\";")
        changed[plat] = (old, new)

if not changed:
    print("watt-toolkit_bin already up to date")
    sys.exit(0)

# recompute hashes for changed URLs
for plat, (old, new) in changed.items():
    um = re.search(rf'({plat} = fetchurl \{{\n\s*url = ")([^"]+)"(;\n\s*hash = ")[^"]*(";)', text)
    if not um:
        print(f"cannot find fetchurl block for {plat}", file=sys.stderr)
        sys.exit(1)
    h = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", um.group(2)],
        capture_output=True,
        text=True,
        check=True,
    )
    text = text.replace(um.group(0), um.group(1) + um.group(2) + um.group(3) + json.loads(h.stdout)["hash"] + um.group(4))
    print(f"watt-toolkit_bin {plat}: {old} -> {new}")

open(path, "w").write(text)
PYEOF
