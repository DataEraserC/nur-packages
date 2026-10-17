#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p nix -p gnused -p gnugrep -p python3
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
NIX_FILE="$SCRIPT_DIR/default.nix"

# Get the latest release tag
LATEST_TAG=$(curl -fsSL "https://github.com/vladelaina/BongoCat/releases.atom" |
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
curl -fsSL "$SRC_URL" -o "$TMPDIR/source.tar.gz"
tar -xzf "$TMPDIR/source.tar.gz" -C "$TMPDIR" --strip-components=1

# Extract a FetchContent URL by content name, searching the whole cmake/
# directory: upstream restructures cmake files between releases (miniz and
# about_webp declarations were dropped entirely in 1.14.0), and a bare grep
# pipeline under `set -e -o pipefail` used to kill the script silently when a
# file disappeared. Fail loudly with the content name instead.
extract_url() {
  local name=$1 url
  url=$(
    grep -rhA2 -E "FetchContent_Declare\(${name}[[:space:])]" "$TMPDIR/cmake/" 2>/dev/null |
      grep -m1 "URL " | sed 's/.*URL //' | tr -d ' \r' || true
  )
  if [ -z "$url" ]; then
    echo "ERROR: FetchContent URL for '$name' not found under cmake/ of ${LATEST_TAG}" >&2
    exit 1
  fi
  printf '%s\n' "$url"
}

echo "Prefetching dependencies..."
SDL3_URL=$(extract_url "SDL3")
YYJSON_URL=$(extract_url "yyjson")
STB_URL=$(extract_url "stb")
MINIAUDIO_URL=$(extract_url "miniaudio")
NUKLEAR_URL=$(extract_url "nuklear")

# Prefetch and convert hashes
prefetch_sri() {
  local url=$1
  local base32
  base32=$(nix-prefetch-url "$url" | tail -1)
  nix hash to-sri --type sha256 "$base32" | head -1
}

SDL3_SRI=$(prefetch_sri "$SDL3_URL")
YYJSON_SRI=$(prefetch_sri "$YYJSON_URL")
STB_SRI=$(prefetch_sri "$STB_URL")
MINIAUDIO_SRI=$(prefetch_sri "$MINIAUDIO_URL")
NUKLEAR_SRI=$(prefetch_sri "$NUKLEAR_URL")

SRC_SRI=$(nix store prefetch-file --json --unpack "$SRC_URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['hash'])")

# Update nix file
python3 <<PYEOF
import re

with open("$NIX_FILE") as f:
    content = f.read()

updates = {
    "version": "$NEW_VERSION",
    "src": "$SRC_SRI",
    ("sdl3-source", "url"): "$SDL3_URL",
    ("sdl3-source", "hash"): "$SDL3_SRI",
    ("yyjson-source", "url"): "$YYJSON_URL",
    ("yyjson-source", "hash"): "$YYJSON_SRI",
    ("stb-source", "url"): "$STB_URL",
    ("stb-source", "hash"): "$STB_SRI",
    ("miniaudio-source", "url"): "$MINIAUDIO_URL",
    ("miniaudio-source", "hash"): "$MINIAUDIO_SRI",
    ("nuklear-source", "url"): "$NUKLEAR_URL",
    ("nuklear-source", "hash"): "$NUKLEAR_SRI",
}

# Update version (the only version = "..." line in the file)
content, n = re.subn(r'(version = ")[^"]*"', rf'\g<1>{updates["version"]}"', content, count=1)
if n != 1 or f'version = "{updates["version"]}";' not in content:
    raise SystemExit("ERROR: version line not rewritten")

# Update src hash (first hash before the closing }; of the fetchFromGitHub
# block). updates["src"] is a full SRI ("sha256-...") while group 1 already
# includes the "sha256-" prefix — strip it or the file gets a doubled prefix
# ("sha256-sha256-...") that fails SRI parsing with "length 0".
src_sri = updates["src"]
if src_sri.startswith("sha256-"):
    src_sri = src_sri[len("sha256-"):]
content, n = re.subn(
    r'(hash = "sha256-)([^"]*)(";\s*\n\s*};\s*\n\s*sdl3)',
    rf'\g<1>{src_sri}\g<3>',
    content, count=1,
)
if n != 1:
    raise SystemExit("ERROR: src hash line not rewritten")

# Update each fetchurl dep block: name = "<dep>-source"; url = "..."; hash = "..."
# Guard BEFORE unpacking: "version"/"src" keys are plain strings and cannot be
# destructured into (name, field).
for key, value in updates.items():
    if isinstance(key, str):
        continue
    name, field = key
    if field == "hash":
        # The dep blocks read name/url/hash on three adjacent lines, so the
        # hash key is never directly below the name key.
        pattern = rf'(name = "{name}";\s*\n\s*url = "[^"]*";\s*\n\s*hash = ")[^"]*(")'
    else:
        pattern = rf'(name = "{name}";\s*\n\s*{field} = ")[^"]*(")'
    content, n = re.subn(pattern, rf'\g<1>{value}\g<2>', content, count=1)
    if n != 1:
        raise SystemExit(f"ERROR: {field} of {name} not rewritten")

with open("$NIX_FILE", "w") as f:
    f.write(content)

print(f"Updated to version {updates['version']}")
PYEOF

echo "Build test: nix build .#BongoCat"
nix build --no-link .#BongoCat
echo "BongoCat update OK"
