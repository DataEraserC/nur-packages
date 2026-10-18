#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p jq -p nix
# shellcheck shell=bash
set -euo pipefail

DIR="$(dirname "$(readlink -f "$0")")"
ATTR_PATH="${UPDATE_NIX_ATTR_PATH:?UPDATE_NIX_ATTR_PATH is not set}"
RELEASES='https://acc-1258344699.cos.accelerate.myqcloud.com/@tencent-ai/codebuddy-code/releases'

NEW_VERSION="$(curl -fsSL "$RELEASES/latest" | tr -d '[:space:]')"
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "codebuddy: unexpected version '${NEW_VERSION}'" >&2
	exit 1
fi

OLD_VERSION="$(jq -r '.version' "$DIR/release.json")"
if [ "$NEW_VERSION" = "$OLD_VERSION" ]; then
	echo "codebuddy: already at ${OLD_VERSION}"
	exit 0
fi

tmp="$(mktemp)"
jq --arg version "$NEW_VERSION" '.version = $version' "$DIR/release.json" >"$tmp"

for system in x86_64-linux aarch64-linux; do
	case "$system" in
	x86_64-linux) arch=x86_64 ;;
	aarch64-linux) arch=arm64 ;;
	esac
	url="${RELEASES}/download/${NEW_VERSION}/codebuddy-code_Linux_${arch}.tar.gz"
	hash="$(nix store prefetch-file --json "$url" | jq -r '.hash')"
	jq --arg system "$system" --arg url "$url" --arg hash "$hash" \
		'.[$system] = { url: $url, hash: $hash }' "$tmp" >"$tmp.new"
	mv "$tmp.new" "$tmp"
done

mv "$tmp" "$DIR/release.json"
echo "codebuddy: updated ${OLD_VERSION} -> ${NEW_VERSION}"

nix build --no-link ".#${ATTR_PATH}"
