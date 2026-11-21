#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p jq -p nix
# shellcheck shell=bash
set -euo pipefail

DIR="$(dirname "$(readlink -f "$0")")"
ATTR_PATH="${UPDATE_NIX_ATTR_PATH:-mobileclaw}"

# The product page's download buttons carry the real endpoint; it answers with a
# 302 to a short-lived SigV4 URL on the object store. The store serves GETs only
# through those signed URLs - a bare object URL answers 403 no matter the user
# agent (verified 2026-11-21) - so both the hash prefetch and release.json must
# go through the endpoint, exactly like default.nix's fetchurl at build time.
# The redirect target is still resolved once (UA-gated) to read the version and
# file name off the object path, but is never fetched or recorded itself.
ENDPOINT='https://zhenze-huhehaote.cmecloud.cn/desktop/manager/public/link/download'

resolve() {
  local os="$1"
  local final
  final="$(curl -fsSL --max-time 60 -H 'User-Agent: Mozilla/5.0' -o /dev/null -w '%{url_effective}' "${ENDPOINT}?os=${os}")"
  printf '%s\n' "${final%%\?*}"
}

x64_url="$(resolve linuxX64Client)"
arm64_url="$(resolve linuxArm64Client)"

for url in "$x64_url" "$arm64_url"; do
  if [ -z "$url" ] || [ "$url" = "$ENDPOINT" ]; then
    echo "mobileclaw: the download endpoint did not redirect for ${url:-<empty>}" >&2
    exit 1
  fi
done

# Digits and dots only: `[^/]*` greedily swallowed the `_x86` out of
# MobileClaw_1.9.8_x86_64.deb (the tail's `_64` still matched the arch
# separator), so every no-op run looked like an update to "1.9.8_x86" and
# failed the 2026-11-21 CI run.
new_version="$(sed -nE 's#.*/MobileClaw_([0-9][0-9.]*)_[a-z0-9_]+\.deb$#\1#p' <<<"$x64_url")"
if [ -z "$new_version" ]; then
  echo "mobileclaw: could not parse the version out of ${x64_url}" >&2
  exit 1
fi

old_version="$(jq -r '.version' "$DIR/release.json")"
if [ "$new_version" = "$old_version" ]; then
  echo "mobileclaw: already at ${old_version}"
  exit 0
fi

tmp="$(mktemp)"
jq --arg version "$new_version" '.version = $version' "$DIR/release.json" >"$tmp"

for os in linuxX64Client linuxArm64Client; do
  case "$os" in
  linuxX64Client)
    system=x86_64-linux
    bare_url="$x64_url"
    ;;
  linuxArm64Client)
    system=aarch64-linux
    bare_url="$arm64_url"
    ;;
  esac
  file="$(basename "$bare_url")"
  hash="$(nix store prefetch-file --json "${ENDPOINT}?os=${os}" | jq -r '.hash')"
  jq --arg system "$system" --arg url "${ENDPOINT}?os=${os}" --arg hash "$hash" --arg file "$file" \
    '.[$system] = { url: $url, file: $file, hash: $hash }' "$tmp" >"$tmp.next"
  mv "$tmp.next" "$tmp"
done

mv "$tmp" "$DIR/release.json"
echo "mobileclaw: ${old_version} -> ${new_version}"
