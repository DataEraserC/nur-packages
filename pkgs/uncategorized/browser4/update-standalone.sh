#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p git -p curl -p nix
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)
REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT=$(cd -- "$SCRIPT_DIR/../../.." && pwd)
fi

REPO_URL="https://github.com/platonai/Browser4"
ASSET="browser4-bundle-runtime-linux-x64.tar.gz"

old_version=$(sed -n '/"version"/{s/.*"version": *"\([^"]*\)".*/\1/p;q}' "$SCRIPT_DIR/sources.json")

tags=$(git ls-remote --tags "$REPO_URL" 'refs/tags/v*') || exit 1

new_version=""
while read -r ver; do
  [ -n "$ver" ] || continue
  if ! curl -fsIL --max-time 30 -o /dev/null "$REPO_URL/releases/download/v$ver/$ASSET"; then
    continue
  fi
  if ! curl -fsSL --max-time 60 -o /dev/null "https://raw.githubusercontent.com/platonai/Browser4/v$ver/cli/browser4-cli/Cargo.lock"; then
    continue
  fi
  new_version="$ver"
  break
done < <(printf '%s\n' "$tags" | sed -n 's#.*refs/tags/v\([0-9][0-9.]*\)$#\1#p' | sort -V -r)

if [ -z "$new_version" ] || [ "$new_version" = "$old_version" ]; then
  exit 0
fi

src_url="$REPO_URL/archive/refs/tags/v$new_version.tar.gz"
runtime_url="$REPO_URL/releases/download/v$new_version/$ASSET"
lock_url="https://raw.githubusercontent.com/platonai/Browser4/v$new_version/cli/browser4-cli/Cargo.lock"

src_hash=$(nix store prefetch-file --json --unpack "$src_url" | sed -n 's/.*"hash": *"\([^"]*\)".*/\1/p')
rt_hash=$(nix store prefetch-file --json "$runtime_url" | sed -n 's/.*"hash": *"\([^"]*\)".*/\1/p')
if [ -z "$src_hash" ] || [ -z "$rt_hash" ]; then
  echo "browser4: failed to compute hashes for $new_version" >&2
  exit 1
fi

backup_dir=$(mktemp -d)
trap 'rm -rf "$backup_dir"' EXIT
cp "$SCRIPT_DIR/sources.json" "$SCRIPT_DIR/Cargo.lock" "$backup_dir"/

curl -fsSL --max-time 120 -o "$backup_dir/Cargo.lock.new" "$lock_url"
if [ ! -s "$backup_dir/Cargo.lock.new" ]; then
  echo "browser4: downloaded Cargo.lock for $new_version is empty" >&2
  exit 1
fi
mv "$backup_dir/Cargo.lock.new" "$SCRIPT_DIR/Cargo.lock"

cat >"$SCRIPT_DIR/sources.json" <<EOF
{
  "browser4": {
    "hash": "$src_hash",
    "tag": "v$new_version",
    "url": "$REPO_URL/archive/refs/tags/v$new_version.tar.gz",
    "version": "$new_version"
  },
  "runtime": {
    "assetName": "$ASSET",
    "hash": "$rt_hash",
    "url": "$runtime_url",
    "version": "$new_version"
  }
}
EOF

if ! (cd "$REPO_ROOT" && nix build ".#browser4" --no-link); then
  cp "$backup_dir/sources.json" "$SCRIPT_DIR/sources.json"
  cp "$backup_dir/Cargo.lock" "$SCRIPT_DIR/Cargo.lock"
  echo "browser4: verification build failed for $new_version, sources.json and Cargo.lock restored" >&2
  exit 1
fi

echo "browser4: updated to $new_version"
