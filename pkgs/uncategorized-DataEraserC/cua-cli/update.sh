#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p git -p nix -p curl -p jq
# shellcheck shell=bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../../.." && pwd)
DEFAULT_NIX="$SCRIPT_DIR/default.nix"
TAG_PREFIX="cua-sdk-v"
UPSTREAM="https://github.com/trycua/cua"
RAW="https://raw.githubusercontent.com/trycua/cua"
source "$REPO_ROOT/tools/github-api.sh"

# The GitHub releases atom feed only lists the ~10 most recent releases,
# which upstream fills with nightly-*/cua-spaces-* tags, so nix-update's
# --version-regex never matches and fails the whole CI run. Read the release
# list instead of the tag list: upstream also pushes cua-sdk-v* tags that
# never get a release object (cua-sdk-v0.31.1), and a tag without a release
# has no downloadable assets, so prefetching it can only fail. The version
# also lives in versionData.tag (there is no `version = "..."` literal for
# nix-update to rewrite), so the tag, the src hash and the skill hashes are
# all maintained here.
CURRENT_TAG=$(
  sed -n "s/^[[:space:]]*tag = \"\(${TAG_PREFIX}[0-9.]*\)\";.*/\1/p" "$DEFAULT_NIX" | head -1
)
[ -n "$CURRENT_TAG" ] || {
  echo "cua-cli: no tag literal in $DEFAULT_NIX" >&2
  exit 1
}

NEW_TAG=$(
  gh_release_tags trycua/cua 100 |
    grep -x "${TAG_PREFIX}[0-9][0-9.]*" |
    sort -V | tail -1
)
[ -n "$NEW_TAG" ] || {
  echo "cua-cli: no ${TAG_PREFIX}* release upstream" >&2
  exit 1
}

[ "$NEW_TAG" = "$CURRENT_TAG" ] && exit 0

NEW_VERSION=${NEW_TAG#"$TAG_PREFIX"}

# A freshly created release can still be uploading its assets: on 2026-11-03
# the cua-sdk-v0.10.1 release existed while cua-cli-0.10.1-linux-x64.tar.gz
# still answered 404, downloadable minutes later. Skip such a release for
# this run (exit 0, nothing written) instead of failing; the next run picks
# it up once the asset is there.
if ! gh_release_assets trycua/cua "$NEW_TAG" | grep -qx "cua-cli-$NEW_VERSION-linux-x64.tar.gz"; then
  echo "cua-cli: release $NEW_TAG has no cua-cli-$NEW_VERSION-linux-x64.tar.gz asset yet; skipping this run" >&2
  exit 0
fi
echo "cua-cli: $CURRENT_TAG -> $NEW_TAG"

# Prefetch with retries: raw.githubusercontent.com can lag a just-pushed
# tag, and transient network failures must not leave a new tag next to
# stale hashes (everything is prefetched before the file is touched).
prefetch() {
  local attempt out
  for attempt in 1 2 3 4; do
    if out=$(nix store prefetch-file --json "$1" 2>/dev/null); then
      printf '%s\n' "$out" | sed -n 's/.*"hash":"\(sha256-[^"]*\)".*/\1/p'
      return 0
    fi
    echo "cua-cli: prefetch attempt $attempt failed: $1" >&2
    if [ "$attempt" -lt 4 ]; then sleep 30; fi
  done
  return 1
}

# Prefetch everything before touching the file so a network failure cannot
# leave a new tag next to stale hashes.
SRC_HASH=$(prefetch "$UPSTREAM/releases/download/$NEW_TAG/cua-cli-$NEW_VERSION-linux-x64.tar.gz") || SRC_HASH=""
[ -n "$SRC_HASH" ] || {
  echo "cua-cli: src prefetch failed" >&2
  exit 1
}

# Hash order in the file: the src tarball first, then one per skill entry.
mapfile -t OLD_HASHES < <(sed -n 's/^[[:space:]]*hash = "\(sha256-[^"]*\)".*/\1/p' "$DEFAULT_NIX")
mapfile -t SKILLS < <(sed -n 's/^[[:space:]]*url = skillUrl "\([^"]*\)".*/\1/p' "$DEFAULT_NIX")
[ "${#OLD_HASHES[@]}" -eq "$((${#SKILLS[@]} + 1))" ] ||
  {
    echo "cua-cli: unexpected hash/skill layout in $DEFAULT_NIX" >&2
    exit 1
  }

SKILL_HASHES=()
for name in "${SKILLS[@]}"; do
  hash=$(prefetch "$RAW/$NEW_TAG/libs/cua/skills/$name") || hash=""
  [ -n "$hash" ] || {
    echo "cua-cli: skill $name prefetch failed" >&2
    exit 1
  }
  SKILL_HASHES+=("$hash")
done

# Rewrite the tag; `version` is derived from it, so the src and skill URLs
# follow automatically.
sed -i "s|tag = \"$CURRENT_TAG\";|tag = \"$NEW_TAG\";|" "$DEFAULT_NIX"
grep -q "tag = \"$NEW_TAG\";" "$DEFAULT_NIX" || {
  echo "cua-cli: tag rewrite failed" >&2
  exit 1
}

sed -i "s|${OLD_HASHES[0]}|$SRC_HASH|" "$DEFAULT_NIX"
for i in "${!SKILL_HASHES[@]}"; do
  sed -i "s|${OLD_HASHES[$((i + 1))]}|${SKILL_HASHES[$i]}|" "$DEFAULT_NIX"
done

# Build once so a bad hash or a broken new release fails here instead of
# waiting for CI.
cd "$REPO_ROOT"
nix build --no-link ".#cua-cli"
