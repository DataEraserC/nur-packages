#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p jq -p nix -p python3
# shellcheck shell=bash
set -euo pipefail

DIR="$(dirname "$(readlink -f "$0")")"
ATTR_PATH="${UPDATE_NIX_ATTR_PATH:?UPDATE_NIX_ATTR_PATH is not set}"
API='https://www.workbuddy.cn/v2/update?platform='

x64="$(curl -fsSL "${API}workbuddy-linux-x64-deb")"
arm64="$(curl -fsSL "${API}workbuddy-linux-arm64-deb")"

NEW_VERSION="$(jq -r '.version' <<<"$x64")"
if [ -z "$NEW_VERSION" ] || [ "$NEW_VERSION" = "null" ]; then
	echo "workbuddy: failed to query the update endpoint" >&2
	exit 1
fi

OLD_VERSION="$(jq -r '.version' "$DIR/release.json")"
if [ "$NEW_VERSION" = "$OLD_VERSION" ]; then
	echo "workbuddy: already at ${OLD_VERSION}"
	exit 0
fi

tmp="$(mktemp)"
jq --arg version "$NEW_VERSION" '.version = $version' "$DIR/release.json" >"$tmp"

for pair in "x86_64-linux:$x64" "aarch64-linux:$arm64"; do
	system="${pair%%:*}"
	payload="${pair#*:}"
	url="$(jq -r '.url' <<<"$payload")"
	hash="$(jq -r '.sha256hash // empty' <<<"$payload")"
	if [ -z "$url" ] || [ "$url" = "null" ]; then
		echo "workbuddy: no download URL for ${system}" >&2
		exit 1
	fi
	if [ -z "$hash" ]; then
		hash="$(nix store prefetch-file --json "$url" | jq -r '.hash')"
	else
		hash="sha256-$(python3 -c 'import base64, sys; print(base64.b64encode(bytes.fromhex(sys.argv[1])).decode())' "$hash")"
	fi
	jq --arg system "$system" --arg url "$url" --arg hash "$hash" \
		'.[$system] = { url: $url, hash: $hash }' "$tmp" >"$tmp.new"
	mv "$tmp.new" "$tmp"
done

mv "$tmp" "$DIR/release.json"
echo "workbuddy: updated ${OLD_VERSION} -> ${NEW_VERSION}"

nix build --no-link ".#${ATTR_PATH}.src"
