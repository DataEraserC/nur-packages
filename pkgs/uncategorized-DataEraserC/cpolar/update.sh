#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p nix -p python3
# shellcheck shell=bash
set -euo pipefail

FILE="$(dirname "$(readlink -f "$0")")/cpolar.nix"
NEW_VERSION=$(curl -fsSL 'https://www.cpolar.com/download' |
  grep -oP 'https://www\.cpolar\.com/static/downloads/releases/\K[0-9.]+(?=/)' | sort -V | tail -n1)
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
text = open(path).read()
old = re.search(r'^  version = "([^"]+)";', text, re.M).group(1)
new = os.environ["NEW_VERSION"]
if old == new:
    print(f"cpolar already at {new}")
    sys.exit(0)

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


block_re = re.compile(
    r'url = "(https://www\.cpolar\.com/static/downloads/releases/[^"]+)";\n(\s*)hash = "[^"]*";'
)
text, n = block_re.subn(repl, text)
open(path, "w").write(text)
print(f"cpolar updated to {new} ({n} hashes)")
PYEOF
