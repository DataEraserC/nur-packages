#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p nix -p gnused -p python3
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
NIX_FILE="$SCRIPT_DIR/default.nix"

# Get the latest release tag
LATEST_TAG=$(curl -sL "https://github.com/vladelaina/BongoCat/releases.atom" |
  sed -n 's|.*<link[^>]*href="https://github.com/vladelaina/BongoCat/releases/tag/\([^"]*\)".*|\1|p' |
  head -1)

NEW_VERSION="${LATEST_TAG#v}"
OLD_VERSION=$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' "$NIX_FILE" | head -1)

if [ "$NEW_VERSION" = "$OLD_VERSION" ]; then
  echo "Already at latest version $NEW_VERSION"
  exit 0
fi

echo "Updating BongoCat: $OLD_VERSION -> $NEW_VERSION"

# Download source to parse FetchContent URLs
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

SRC_URL="https://github.com/vladelaina/BongoCat/archive/refs/tags/${LATEST_TAG}.tar.gz"
curl -sL "$SRC_URL" -o "$TMPDIR/source.tar.gz"
tar -xzf "$TMPDIR/source.tar.gz" -C "$TMPDIR" --strip-components=1

# Extract FetchContent URLs from cmake files
extract_url() {
  grep -A2 "FetchContent_Declare($1" "$TMPDIR/cmake/$2" 2>/dev/null |
    grep "URL " | head -1 | sed 's/.*URL //' | tr -d ' '
}

SDL3_URL=$(extract_url "SDL3" "Dependencies.cmake")
YYJSON_URL=$(extract_url "yyjson" "Dependencies.cmake")
STB_URL=$(extract_url "stb" "Dependencies.cmake")
MINIAUDIO_URL=$(extract_url "miniaudio" "Dependencies.cmake")
NUKLEAR_URL=$(extract_url "nuklear" "Dependencies.cmake")
MINIZ_URL=$(extract_url "miniz" "Archive.cmake")
WEBP_URL=$(extract_url "about_webp" "AboutWebP.cmake")

# Prefetch and convert hashes
prefetch_sri() {
  local url=$1
  local base32
  base32=$(nix-prefetch-url "$url" 2>/dev/null | tail -1)
  nix hash to-sri --type sha256 "$base32" 2>/dev/null | head -1
}

echo "Prefetching dependencies..."
SDL3_SRI=$(prefetch_sri "$SDL3_URL")
YYJSON_SRI=$(prefetch_sri "$YYJSON_URL")
STB_SRI=$(prefetch_sri "$STB_URL")
MINIAUDIO_SRI=$(prefetch_sri "$MINIAUDIO_URL")
NUKLEAR_SRI=$(prefetch_sri "$NUKLEAR_URL")
MINIZ_SRI=$(prefetch_sri "$MINIZ_URL")
WEBP_SRI=$(prefetch_sri "$WEBP_URL")

SRC_SRI=$(nix store prefetch-file --json --unpack "$SRC_URL" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['hash'])")

# Update nix file
python3 <<PYEOF
import re

with open("$NIX_FILE") as f:
    content = f.read()

updates = {
    "version": "$NEW_VERSION",
    "src": "$SRC_SRI",
    ("SDL3", "url"): "$SDL3_URL",
    ("SDL3", "hash"): "$SDL3_SRI",
    ("yyjson-source", "url"): "$YYJSON_URL",
    ("yyjson-source", "hash"): "$YYJSON_SRI",
    ("stb-source", "url"): "$STB_URL",
    ("stb-source", "hash"): "$STB_SRI",
    ("miniaudio-source", "url"): "$MINIAUDIO_URL",
    ("miniaudio-source", "hash"): "$MINIAUDIO_SRI",
    ("nuklear-source", "url"): "$NUKLEAR_URL",
    ("nuklear-source", "hash"): "$NUKLEAR_SRI",
    ("miniz-source", "url"): "$MINIZ_URL",
    ("miniz-source", "hash"): "$MINIZ_SRI",
    ("libwebp-source", "url"): "$WEBP_URL",
    ("libwebp-source", "hash"): "$WEBP_SRI",
}

# Update version
content = re.sub(r'(version = ")[^"]*"', rf'\g<1>{updates["version"]}"', content)

# Update src hash (first occurrence after hash = "sha256-)
content = re.sub(
    r'(hash = "sha256-)([^"]*)(";\s*\n\s*};\s*\n\s*sdl3)',
    rf'\g<1>{updates["src"]}\g<3>',
    content, count=1
)

# Update each dep block: name = "xxx"; url = "..."; hash = "..."
for (name, field), value in updates.items():
    if isinstance(name, tuple):
        dep_name, field = name
        pattern = rf'(name = "{dep_name}";\s*\n\s*{field} = ")[^"]*(")'
        content = re.sub(pattern, rf'\g<1>{value}\g<2>', content)

with open("$NIX_FILE", "w") as f:
    f.write(content)

print(f"Updated to version {updates['version']}")
PYEOF

echo "Build test: nix build .#BongoCat"
