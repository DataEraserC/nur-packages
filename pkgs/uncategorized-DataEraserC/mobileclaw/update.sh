#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p jq -p nix
# shellcheck shell=bash
set -euo pipefail

DIR="$(dirname "$(readlink -f "$0")")"
ATTR_PATH="${UPDATE_NIX_ATTR_PATH:-mobileclaw}"

# The product page's download buttons carry the real endpoint; it answers with a
# 302 to a short-lived SigV4 URL on the object store. Follow the redirect once,
# strip the signature, and derive the version from the filename, so the version
# does not depend on keeping a second copy of it in release.json.
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

new_version="$(sed -nE 's#.*/MobileClaw_([0-9][^/]*)_[a-z0-9_]+\.deb$#\1#p' <<<"$x64_url")"
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

for pair in "x86_64-linux:${x64_url}" "aarch64-linux:${arm64_url}"; do
  system="${pair%%:*}"
  url="${pair#*:}"
  hash="$(nix store prefetch-file --json "$url" | jq -r '.hash')"
  jq --arg system "$system" --arg url "$url" --arg hash "$hash" \
    '.[$system] = { url: $url, hash: $hash }' "$tmp" >"$tmp.next"
  mv "$tmp.next" "$tmp"
done

mv "$tmp" "$DIR/release.json"
echo "mobileclaw: ${old_version} -> ${new_version}"
