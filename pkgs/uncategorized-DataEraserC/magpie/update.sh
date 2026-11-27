#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p python3
# shellcheck shell=bash
set -euo pipefail

# Rewrite sources.nix from the latest yetone/magpie-releases SHA256SUMS.
# Both packages (magpie, magpie-cli) read the same file.

DIR="$(dirname "$(readlink -f "$0")")"
FILE="$DIR/sources.nix"
REPO="yetone/magpie-releases"
ASSETS=(
	magpie-linux-amd64
	magpie-linux-arm64
	magpie-cli-linux-amd64
	magpie-cli-linux-arm64
)

tag="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])')"
version="${tag#v}"
if [ -z "$version" ]; then
	echo "magpie: failed to read the latest release tag" >&2
	exit 1
fi

sums="$(curl -fsSL "https://github.com/$REPO/releases/download/$tag/SHA256SUMS")"

old_version="$(sed -n 's/^  version = "\([^"]*\)";/\1/p' "$FILE" | head -n1)"

changed=0
[ "$old_version" = "$version" ] || changed=1
for asset in "${ASSETS[@]}"; do
	hash="$(awk -v a="$asset" '$2 == a { print $1 }' <<<"$sums")"
	if [ -z "$hash" ]; then
		echo "magpie: $asset missing from $tag/SHA256SUMS" >&2
		exit 1
	fi
	current="$(sed -n "s/^    $asset = \"\([^\"]*\)\";/\1/p" "$FILE")"
	[ "$current" = "$hash" ] || changed=1
done

if [ "$changed" -eq 0 ]; then
	echo "magpie: already at $version"
	exit 0
fi

python3 - "$FILE" "$version" "$sums" "${ASSETS[@]}" <<'PY'
import re
import sys

path, version, sums, *assets = sys.argv[1:]
hashes = {}
for line in sums.splitlines():
    parts = line.split()
    if len(parts) == 2:
        hashes[parts[1]] = parts[0]

text = open(path).read()
text, n = re.subn(r'(?m)^  version = "[^"]+";', f'  version = "{version}";', text, count=1)
if n != 1:
    sys.exit("magpie: version line not found in sources.nix")
for asset in assets:
    text, n = re.subn(
        rf'(?m)^    {re.escape(asset)} = "[^"]+";',
        f'    {asset} = "{hashes[asset]}";',
        text,
        count=1,
    )
    if n != 1:
        sys.exit(f"magpie: {asset} line not found in sources.nix")
open(path, "w").write(text)
PY

echo "magpie: $old_version -> $version"
