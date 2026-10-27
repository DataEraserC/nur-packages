#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p git -p nix
# shellcheck shell=bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../../.." && pwd)
DEFAULT_NIX="$SCRIPT_DIR/default.nix"
TAG_PREFIX="cua-driver-rs-v"
UPSTREAM="https://github.com/trycua/cua"

# The GitHub releases atom feed only lists the ~10 most recent releases,
# which upstream fills with nightly-cua-driver-rs-*/cua-spaces-*/nightly-lume-*
# tags, so nix-update's --version-regex never matches and fails the whole CI
# run; read the full tag list instead. The version also lives in
# versionData.tag (there is no `version = "..."` literal for nix-update to
# rewrite), so the tag, the src hash and the skills hash are all maintained
# here.
NEW_TAG=$(
  git ls-remote --tags "$UPSTREAM" |
    sed -n "s#.*refs/tags/\(${TAG_PREFIX}[0-9][0-9.]*\)\$#\1#p" |
    sort -V | tail -1
)
[ -n "$NEW_TAG" ] || { echo "cua-driver: no ${TAG_PREFIX}* tag upstream" >&2; exit 1; }

CURRENT_TAG=$(
  sed -n "s/^[[:space:]]*tag = \"\(${TAG_PREFIX}[0-9.]*\)\";.*/\1/p" "$DEFAULT_NIX" | head -1
)
[ -n "$CURRENT_TAG" ] || { echo "cua-driver: no tag literal in $DEFAULT_NIX" >&2; exit 1; }

[ "$NEW_TAG" = "$CURRENT_TAG" ] && exit 0

echo "cua-driver: $CURRENT_TAG -> $NEW_TAG"

prefetch() {
  nix store prefetch-file --json "$1" | sed -n 's/.*"hash":"\(sha256-[^"]*\)".*/\1/p'
}

# Prefetch everything before touching the file so a network failure cannot
# leave a new tag next to stale hashes.
SRC_HASH=$(prefetch "$UPSTREAM/archive/refs/tags/$NEW_TAG.tar.gz")
[ -n "$SRC_HASH" ] || { echo "cua-driver: src prefetch failed" >&2; exit 1; }
SKILLS_HASH=$(prefetch "$UPSTREAM/releases/download/$NEW_TAG/$NEW_TAG-skills.tar.gz")
[ -n "$SKILLS_HASH" ] || { echo "cua-driver: skills prefetch failed" >&2; exit 1; }

OLD_SRC_HASH=$(
  sed -n 's/^[[:space:]]*hash = "\(sha256-[^"]*\)".*/\1/p' "$DEFAULT_NIX" | head -1
)
OLD_SKILLS_HASH=$(
  sed -n 's/^[[:space:]]*skillsHash = "\(sha256-[^"]*\)".*/\1/p' "$DEFAULT_NIX" | head -1
)
[ -n "$OLD_SRC_HASH" ] && [ -n "$OLD_SKILLS_HASH" ] ||
  { echo "cua-driver: no hash literals in $DEFAULT_NIX" >&2; exit 1; }

# Rewrite the tag; `version` is derived from it, so the src URL follows
# automatically.
sed -i "s|tag = \"$CURRENT_TAG\";|tag = \"$NEW_TAG\";|" "$DEFAULT_NIX"
grep -q "tag = \"$NEW_TAG\";" "$DEFAULT_NIX" || { echo "cua-driver: tag rewrite failed" >&2; exit 1; }

sed -i "s|$OLD_SRC_HASH|$SRC_HASH|" "$DEFAULT_NIX"
sed -i "s|$OLD_SKILLS_HASH|$SKILLS_HASH|" "$DEFAULT_NIX"

# Build once so a bad hash or a broken new release fails here instead of
# waiting for CI.
cd "$REPO_ROOT"
nix build --no-link ".#cua-driver"
