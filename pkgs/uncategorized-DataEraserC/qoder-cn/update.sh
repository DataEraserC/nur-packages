#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p jq -p nix -p dpkg -p python3
# shellcheck shell=bash
set -euo pipefail

DIR="$(dirname "$(readlink -f "$0")")"
FILE="$DIR/default.nix"
URL="https://qoder-ide-cn.oss-cn-hangzhou.aliyuncs.com/qoder/release/lastest/qoder-cn-ide_amd64.deb"

info="$(nix store prefetch-file --json "$URL")"
hash="$(jq -r '.hash' <<<"$info")"
store="$(jq -r '.storePath' <<<"$info")"
version="$(dpkg-deb -f "$store" Version)"

old_version="$(sed -n 's/^  version = "\([^"]*\)";/\1/p' "$FILE" | head -n1)"
old_hash="$(sed -n 's/^  hash = "\([^"]*\)";/\1/p' "$FILE" | head -n1)"

if [ "$old_version" = "$version" ] && [ "$old_hash" = "$hash" ]; then
  echo "qoder-cn: already at ${version}"
  exit 0
fi

python3 - "$FILE" "$version" "$hash" <<'PYEOF'
import re
import sys

path, version, hash = sys.argv[1:]
text = open(path).read()
text, version_count = re.subn(
    r'(?m)^  version = "[^"]+";', f'  version = "{version}";', text, count=1
)
text, hash_count = re.subn(
    r'(?m)^  hash = "[^"]+";', f'  hash = "{hash}";', text, count=1
)
if version_count != 1 or hash_count != 1:
    raise SystemExit("qoder-cn: failed to update version/hash")
open(path, "w").write(text)
PYEOF

echo "qoder-cn: updated ${old_version} -> ${version}"

if [ -n "${UPDATE_NIX_ATTR_PATH:-}" ]; then
  nix build --no-link ".#${UPDATE_NIX_ATTR_PATH}"
fi
