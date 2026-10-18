#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p jq -p nix
# shellcheck shell=bash
set -euo pipefail

DIR="$(dirname "$(readlink -f "$0")")"
ATTR_PATH="${UPDATE_NIX_ATTR_PATH:?UPDATE_NIX_ATTR_PATH is not set}"
VERSION_INFO='https://cnnorth4-cloudide-marketplace.obs.cn-north-4.myhuaweicloud.com/codearts/cli_tui/install_script/codearts_cli_versioninfo_v1.0.json'

info="$(curl -fsSL "$VERSION_INFO")"

url_for() {
	jq -r --arg os "$1" --arg arch "$2" \
		'[.[] | select(.os == $os and .arch == $arch)][0].url // empty' <<<"$info"
}

X64_URL="$(url_for linux x64)"
ARM64_URL="$(url_for linux arm64)"
if [ -z "$X64_URL" ] || [ -z "$ARM64_URL" ]; then
	echo "codearts: failed to resolve Linux download URLs" >&2
	exit 1
fi

NEW_VERSION="$(sed -n 's/.*codearts-install-\([0-9.]*\)-linux-x64\.tar\.gz/\1/p' <<<"$X64_URL")"
if [ -z "$NEW_VERSION" ]; then
	echo "codearts: failed to parse version from '${X64_URL}'" >&2
	exit 1
fi

OLD_VERSION="$(jq -r '.version' "$DIR/release.json")"
if [ "$NEW_VERSION" = "$OLD_VERSION" ]; then
	echo "codearts: already at ${OLD_VERSION}"
	exit 0
fi

tmp="$(mktemp)"
jq --arg version "$NEW_VERSION" '.version = $version' "$DIR/release.json" >"$tmp"

for pair in "x86_64-linux:$X64_URL" "aarch64-linux:$ARM64_URL"; do
	system="${pair%%:*}"
	url="${pair#*:}"
	hash="$(nix store prefetch-file --json "$url" | jq -r '.hash')"
	jq --arg system "$system" --arg url "$url" --arg hash "$hash" \
		'.[$system] = { url: $url, hash: $hash }' "$tmp" >"$tmp.new"
	mv "$tmp.new" "$tmp"
done

mv "$tmp" "$DIR/release.json"
echo "codearts: updated ${OLD_VERSION} -> ${NEW_VERSION}"

nix build --no-link ".#${ATTR_PATH}"
