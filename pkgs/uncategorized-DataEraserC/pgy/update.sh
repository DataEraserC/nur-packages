#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p jq -p nix -p python3
# shellcheck shell=bash
set -euo pipefail

FILE="$(find "$(dirname "$(readlink -f "$0")")" -maxdepth 1 -name '*.nix' ! -name 'default.nix' | head -n1)"
NEW_VERSION=$(curl -fsSL 'https://clientapi.sdwan.oray.com/softwares/PGY_VISITORENT_LINUX?x64=0&versiontype=stable&channel=0' |
  grep -oP '"versionno"\s*:\s*"\K[0-9.]+' | head -n1)
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
old = re.search(r'^  version = "([^"]+)";', open(path).read(), re.M).group(1)
new = os.environ["NEW_VERSION"]
if old == new:
    print(f"pgy already at {new}")
    sys.exit(0)

text = open(path).read()
text = text.replace(f"PgyVisitor-{old}-", f"PgyVisitor-{new}-")
text = text.replace(f'version = "{old}";', f'version = "{new}";')


def prefetch(url):
    out = subprocess.run(
        ["nix", "store", "prefetch-file", "--json", url],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(out.stdout)["hash"]


def repl(m):
    return f'url = "{m.group(1)}";\n{m.group(2)}hash = "{prefetch(m.group(1))}";'


block_re = re.compile(r'url = "(https://dl\.oray\.com/pgy/linux/[^"]+)";\n(\s*)hash = "[^"]*";')
text, _ = block_re.subn(repl, text)
open(path, "w").write(text)
print(f"pgy updated to {new}")
PYEOF
