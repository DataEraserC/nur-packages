#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p yq -p python3
# shellcheck shell=bash
set -euo pipefail

DIR="$(dirname "$(readlink -f "$0")")"
FILE="$DIR/default.nix"
BASE="https://autoglm-public-oss.z.ai/zwork/updates/production/official/linux-x64"
MANIFEST="$BASE/latest-linux.yml"

info="$(curl -fsSL "$MANIFEST")"
version="$(yq -r '.version' <<<"$info")"
file="$(yq -r '.files[0].url' <<<"$info")"
digest="$(yq -r '.files[0].sha512' <<<"$info")"
if [ -z "$version" ] || [ "$version" = "null" ] || [ -z "$file" ] || [ "$file" = "null" ]; then
  echo "autoclaw-intl: failed to parse ${MANIFEST}" >&2
  exit 1
fi
url="$BASE/$file"
hash="sha512-$digest"

old_version="$(sed -n 's/^  version = "\([^"]*\)";/\1/p' "$FILE" | head -n1)"
old_url="$(sed -n 's/^  url = "\([^"]*\)";/\1/p' "$FILE" | head -n1)"
old_hash="$(sed -n 's/^  hash = "\([^"]*\)";/\1/p' "$FILE" | head -n1)"

if [ "$old_version" = "$version" ] && [ "$old_url" = "$url" ] && [ "$old_hash" = "$hash" ]; then
  echo "autoclaw-intl: already at ${version}"
  exit 0
fi

python3 - "$FILE" "$version" "$url" "$hash" <<'PYEOF'
import re
import sys

path, version, url, hash = sys.argv[1:]
text = open(path).read()
for field, value in (("version", version), ("url", url), ("hash", hash)):
    text, count = re.subn(
        rf'(?m)^  {field} = "[^"]+";', f'  {field} = "{value}";', text, count=1
    )
    if count != 1:
        raise SystemExit(f"autoclaw-intl: failed to update {field}")
open(path, "w").write(text)
PYEOF

echo "autoclaw-intl: updated ${old_version} -> ${version}"

if [ -n "${UPDATE_NIX_ATTR_PATH:-}" ]; then
  nix build --no-link ".#${UPDATE_NIX_ATTR_PATH}"
fi
