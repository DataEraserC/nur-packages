#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p git -p nix
# shellcheck shell=bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../../.." && pwd)
DEFAULT_NIX="$SCRIPT_DIR/default.nix"
TAG_PREFIX="cua-sdk-v"
UPSTREAM="https://github.com/trycua/cua"
RAW="https://raw.githubusercontent.com/trycua/cua"

# The GitHub releases atom feed only lists the ~10 most recent releases,
# which upstream fills with nightly-*/cua-spaces-* tags, so nix-update's
# --version-regex never matches and fails the whole CI run; read the full
# tag list instead. The version also lives in versionData.tag (there is no
# `version = "..."` literal for nix-update to rewrite), so the tag, the src
# hash and the skill hashes are all maintained here.
NEW_TAG=$(
  git ls-remote --tags "$UPSTREAM" |
    sed -n "s#.*refs/tags/\(${TAG_PREFIX}[0-9][0-9.]*\)\$#\1#p" |
    sort -V | tail -1
)
[ -n "$NEW_TAG" ] || { echo "cua-cli: no ${TAG_PREFIX}* tag upstream" >&2; exit 1; }

CURRENT_TAG=$(
  sed -n "s/^[[:space:]]*tag = \"\(${TAG_PREFIX}[0-9.]*\)\";.*/\1/p" "$DEFAULT_NIX" | head -1
)
[ -n "$CURRENT_TAG" ] || { echo "cua-cli: no tag literal in $DEFAULT_NIX" >&2; exit 1; }

[ "$NEW_TAG" = "$CURRENT_TAG" ] && exit 0

NEW_VERSION=${NEW_TAG#"$TAG_PREFIX"}
echo "cua-cli: $CURRENT_TAG -> $NEW_TAG"

prefetch() {
  nix store prefetch-file --json "$1" | sed -n 's/.*"hash":"\(sha256-[^"]*\)".*/\1/p'
}

# Prefetch everything before touching the file so a network failure cannot
# leave a new tag next to stale hashes.
SRC_HASH=$(prefetch "$UPSTREAM/releases/download/$NEW_TAG/cua-cli-$NEW_VERSION-linux-x64.tar.gz")
[ -n "$SRC_HASH" ] || { echo "cua-cli: src prefetch failed" >&2; exit 1; }

# Hash order in the file: the src tarball first, then one per skill entry.
mapfile -t OLD_HASHES < <(sed -n 's/^[[:space:]]*hash = "\(sha256-[^"]*\)".*/\1/p' "$DEFAULT_NIX")
mapfile -t SKILLS < <(sed -n 's/^[[:space:]]*url = skillUrl "\([^"]*\)".*/\1/p' "$DEFAULT_NIX")
[ "${#OLD_HASHES[@]}" -eq "$((${#SKILLS[@]} + 1))" ] ||
  { echo "cua-cli: unexpected hash/skill layout in $DEFAULT_NIX" >&2; exit 1; }

SKILL_HASHES=()
for name in "${SKILLS[@]}"; do
  hash=$(prefetch "$RAW/$NEW_TAG/libs/cua/skills/$name")
  [ -n "$hash" ] || { echo "cua-cli: skill $name prefetch failed" >&2; exit 1; }
  SKILL_HASHES+=("$hash")
done

# Rewrite the tag; `version` is derived from it, so the src and skill URLs
# follow automatically.
sed -i "s|tag = \"$CURRENT_TAG\";|tag = \"$NEW_TAG\";|" "$DEFAULT_NIX"
grep -q "tag = \"$NEW_TAG\";" "$DEFAULT_NIX" || { echo "cua-cli: tag rewrite failed" >&2; exit 1; }

sed -i "s|${OLD_HASHES[0]}|$SRC_HASH|" "$DEFAULT_NIX"
for i in "${!SKILL_HASHES[@]}"; do
  sed -i "s|${OLD_HASHES[$((i + 1))]}|${SKILL_HASHES[$i]}|" "$DEFAULT_NIX"
done

# Build once so a bad hash or a broken new release fails here instead of
# waiting for CI.
cd "$REPO_ROOT"
nix build --no-link ".#cua-cli"
