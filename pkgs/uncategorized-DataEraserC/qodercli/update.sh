#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p jq -p nix
# shellcheck shell=bash
set -euo pipefail

# `channels/manifest.json` is the feed `qodercli update` polls; the per-asset
# sha256 is the same digest `nix store prefetch-file` reports for that URL.
DIR="$(dirname "$(readlink -f "$0")")"
ATTR_PATH="${UPDATE_NIX_ATTR_PATH:?UPDATE_NIX_ATTR_PATH is not set}"
PKG="qodercli"
MANIFEST='https://download.qoder.com/qodercli/channels/manifest.json'
RELEASE="$DIR/release.json"

manifest="$(mktemp -t "${PKG}-manifest-XXXXXX.json")"
tmp="$RELEASE.tmp"
entry="$RELEASE.tmp.entry"
trap 'rm -f "$manifest" "$tmp" "$entry"' EXIT

curl -fsSL "$MANIFEST" -o "$manifest"

new_version="$(jq -er '.latest | select(type == "string")' "$manifest")"
if ! [[ $new_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "${PKG}: unexpected version '${new_version}'" >&2
  exit 1
fi

old_version="$(jq -er '.version' "$RELEASE")"
if [ "$new_version" = "$old_version" ]; then
  echo "${PKG}: already at ${old_version}"
  exit 0
fi

jq --arg version "$new_version" '.version = $version' "$RELEASE" >"$tmp"

for system in x86_64-linux aarch64-linux; do
  case "$system" in
  x86_64-linux) arch=amd64 ;;
  aarch64-linux) arch=arm64 ;;
  esac
  asset="$(jq -c --arg arch "$arch" '
		[ .files[] | select(.os == "linux" and .arch == $arch) ]
		| if length == 1 then .[0] else error("no single linux/" + $arch + " asset") end
	' "$manifest")"
  url="$(jq -er '.url | select(startswith("https://"))' <<<"$asset")"
  hex="$(jq -er '.sha256 | select(test("^[0-9a-f]{64}$"))' <<<"$asset")"
  hash="$(nix hash convert --hash-algo sha256 --to sri "$hex")"
  jq --arg system "$system" --arg url "$url" --arg hash "$hash" \
    '.[$system] = { url: $url, hash: $hash }' "$tmp" >"$entry"
  mv "$entry" "$tmp"
done

chmod 0644 "$tmp"
mv "$tmp" "$RELEASE"
echo "${PKG}: updated ${old_version} -> ${new_version}"

nix build --no-link ".#${ATTR_PATH}"
