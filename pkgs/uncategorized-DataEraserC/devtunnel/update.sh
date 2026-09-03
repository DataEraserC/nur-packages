#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p jq -p nix -p python3
# shellcheck shell=bash
set -euo pipefail

FILE="$(dirname "$(readlink -f "$0")")/devtunnel.nix"
NEW_VERSION=$(curl -fsSL 'https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/m/Microsoft/devtunnel' |
  jq -r '.[].name' |
  grep -oP '1\.0\.[0-9]+\+[a-f0-9]+' |
  sort -V |
  tail -n1)
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
    print(f"devtunnel already at {new}")
    sys.exit(0)

text = open(path).read()
text = text.replace(f"/cli/{old}/", f"/cli/{new}/")
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
    r'url = "(https://tunnelsassetsprod\.blob\.core\.windows\.net/cli/[^"]+)";\n(\s*)hash = "[^"]*";'
)
text, n = block_re.subn(repl, text)
open(path, "w").write(text)
print(f"devtunnel updated to {new}")
PYEOF
