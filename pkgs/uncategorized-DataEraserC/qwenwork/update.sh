#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p jq -p nix -p dpkg
# shellcheck shell=bash
set -euo pipefail

# 千问办公 desktop app. Both Linux debs live on fixed "latest" object keys of
# the asset bucket (https://qwenwork.cn download buttons), so the URL is stable
# and the deb's own control Version (not a filename, not the release-notes
# page - the notes run ahead of the objects: 2026-11-28 they list 2.3.2 while
# `latest` still serves 2.0.2-26111601) is the authoritative version.
#
# The bucket answers HEADs with an ETag, so a run starts with a cheap probe:
# both ETags unchanged means "already at" without downloading ~400MB per arch.
# Either one changed (upstream re-uploads both together per release) downloads
# both debs, hashes them and reads the version out of the control member,
# keeping version and bytes one fact. The probe is also what keeps a no-op run
# from re-fetching when the bucket re-uploads in place.
#
# Per-arch values ride on parallel indexed arrays and case dispatch, not on
# associative arrays: the system keys carry a hyphen (x86_64-linux), and the
# treefmt shell formatter rewrites `[x86_64-linux]` into `[x86_64 - linux]`,
# turning the subscript into arithmetic and silently destroying every lookup.
DIR="$(dirname "$(readlink -f "$0")")"
ATTR_PATH="${UPDATE_NIX_ATTR_PATH:?UPDATE_NIX_ATTR_PATH is not set}"
PKG="qwenwork"
RELEASE="$DIR/release.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SYSTEMS=(x86_64-linux aarch64-linux)

url_for() {
	case "$1" in
	x86_64-linux) printf '%s\n' "https://assets.qwenwork.cn/release/latest/qwenworkcn-linux-amd64.deb" ;;
	aarch64-linux) printf '%s\n' "https://assets.qwenwork.cn/release/latest/qwenworkcn-linux-arm64.deb" ;;
	*) return 1 ;;
	esac
}

file_for() {
	case "$1" in
	x86_64-linux) printf '%s\n' "qwenworkcn-linux-amd64.deb" ;;
	aarch64-linux) printf '%s\n' "qwenworkcn-linux-arm64.deb" ;;
	*) return 1 ;;
	esac
}

# Distinguish "removed" (404/410 - hard fail, upstream deleted or renamed the
# object) from transport trouble (retry, then skip without writing anything -
# no write means no unverified hash; the next run re-probes).
probe_etag() {
	local url="$1" attempt code etag
	for attempt in 1 2 3; do
		code="$(curl -sS -o /dev/null -w '%{http_code}' -I --max-time 60 "$url" || true)"
		case "$code" in
		200)
			etag="$(curl -fsSI --max-time 60 "$url" | tr -d '\r' | sed -n 's/^[Ee][Tt][Aa][Gg]: *//p')"
			if [ -n "$etag" ]; then
				printf '%s\n' "$etag"
				return 0
			fi
			;;
		404 | 410)
			echo "$PKG: $url answers HTTP $code (removed or renamed)" >&2
			return 2
			;;
		esac
		sleep $((attempt * 5))
	done
	return 1
}

changed=0
for index in "${!SYSTEMS[@]}"; do
	system="${SYSTEMS[index]}"
	old_etag="$(jq -er --arg system "$system" '.[$system].etag // ""' "$RELEASE")"
	url="$(url_for "$system")"
	set +e
	new_etag="$(probe_etag "$url")"
	probe_status=$?
	set -e
	case "$probe_status" in
	0) ;;
	2) exit 1 ;;
	*)
		echo "$PKG: the asset bucket did not answer a HEAD for $(file_for "$system"); leaving release.json untouched" >&2
		exit 0
		;;
	esac
	if [ "$new_etag" = "$old_etag" ]; then
		echo "$PKG: $(file_for "$system") unchanged (etag $new_etag)"
	else
		changed=1
	fi
	NEW_ETAGS[index]="$new_etag"
done

if [ "$changed" = 0 ]; then
	echo "$PKG: already at $(jq -r '.version' "$RELEASE")"
	exit 0
fi

for index in "${!SYSTEMS[@]}"; do
	system="${SYSTEMS[index]}"
	deb="$TMP/$(file_for "$system")"
	curl -fSL --retry 3 --retry-delay 10 --max-time 3600 "$(url_for "$system")" -o "$deb"
	hex="$(sha256sum "$deb" | cut -d' ' -f1)"
	NEW_HASHES[index]="$(nix hash convert --hash-algo sha256 --to sri "$hex")"
	NEW_VERSIONS[index]="$(dpkg-deb -f "$deb" Version)"
done

if [ "${NEW_VERSIONS[0]}" != "${NEW_VERSIONS[1]}" ]; then
	echo "$PKG: the amd64 and arm64 debs disagree on version (${NEW_VERSIONS[0]} vs ${NEW_VERSIONS[1]})" >&2
	exit 1
fi
new_version="${NEW_VERSIONS[0]}"
if ! [[ $new_version =~ ^[0-9][0-9.]*(-[0-9]+)?$ ]]; then
	echo "$PKG: unexpected version '$new_version'" >&2
	exit 1
fi

old_version="$(jq -r '.version' "$RELEASE")"
tmp="$RELEASE.tmp"
jq --arg version "$new_version" '.version = $version' "$RELEASE" >"$tmp"
for index in "${!SYSTEMS[@]}"; do
	system="${SYSTEMS[index]}"
	jq --arg system "$system" --arg etag "${NEW_ETAGS[index]}" --arg hash "${NEW_HASHES[index]}" \
		'.[$system].hash = $hash | .[$system].etag = $etag' "$tmp" >"$tmp.next"
	mv "$tmp.next" "$tmp"
done

chmod 0644 "$tmp"
mv "$tmp" "$RELEASE"
echo "$PKG: updated ${old_version} -> ${new_version}"

# Verify the freshly written hashes by building, so a bad entry never reaches a
# commit (the URL is unchanged, only the object behind it moved).
ROOT="$(git -C "$DIR" rev-parse --show-toplevel)"
(cd "$ROOT" && nix build --no-link ".#${ATTR_PATH}")
