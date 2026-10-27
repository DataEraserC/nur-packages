#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p git -p nix
# shellcheck shell=bash
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../../.." && pwd)
DEFAULT_NIX="$SCRIPT_DIR/default.nix"
TAG_PREFIX="cua-driver-rs-v"
UPSTREAM="https://github.com/trycua/cua"
# Placeholder for the FOD-echo below: the build fails and reports the real
# hash on the "got:" line.
DUMMY_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# The GitHub releases atom feed only lists the ~10 most recent releases,
# which upstream fills with nightly-cua-driver-rs-*/cua-spaces-*/nightly-lume-*
# tags, so nix-update's --version-regex never matches and fails the whole CI
# run; read the full tag list instead. The version also lives in
# versionData.tag (there is no `version = "..."` literal for nix-update to
# rewrite), so the tag and both hashes are all maintained here.
NEW_TAG=$(
  git ls-remote --tags "$UPSTREAM" |
    sed -n "s#.*refs/tags/\(${TAG_PREFIX}[0-9][0-9.]*\)\$#\1#p" |
    sort -V | tail -1
)
[ -n "$NEW_TAG" ] || { echo "cua-driver: no ${TAG_PREFIX}* tag upstream" >&2; exit 1; }
export NEW_TAG

CURRENT_TAG=$(
  sed -n "s/^[[:space:]]*tag = \"\(${TAG_PREFIX}[0-9.]*\)\";.*/\1/p" "$DEFAULT_NIX" | head -1
)
[ -n "$CURRENT_TAG" ] || { echo "cua-driver: no tag literal in $DEFAULT_NIX" >&2; exit 1; }

OLD_SRC_HASH=$(
  sed -n 's/^[[:space:]]*hash = "\(sha256-[^"]*\)".*/\1/p' "$DEFAULT_NIX" | head -1
)
OLD_SKILLS_HASH=$(
  sed -n 's/^[[:space:]]*skillsHash = "\(sha256-[^"]*\)".*/\1/p' "$DEFAULT_NIX" | head -1
)
[ -n "$OLD_SRC_HASH" ] && [ -n "$OLD_SKILLS_HASH" ] ||
  { echo "cua-driver: no hash literals in $DEFAULT_NIX" >&2; exit 1; }

# Compute a fixed-output hash with the package's own fetcher: build the
# fetcher with a dummy hash and read the real hash back from the "got:" line
# (the method nix-update uses internally; see the "tarball prefetch 哈希"
# section of the root AGENTS.md).
#
# `nix store prefetch-file` must NOT be used for the src archive: GitHub
# generates archive/refs/tags/*.tar.gz on the fly, and the host-side download
# sees a different byte-variant than the sandboxed build does (verified
# 2026-10-27 for this very tag: prefetch sha256-w8pz... vs build
# sha256-Fpryc..., each stable), so a prefetched hash fails the fixed-output
# check. Release assets are byte-stable, but the echo is used for both so
# there is only one mechanism.
fod_hash() {
  nix build --no-link --impure --expr "$1" 2>&1 |
    sed -n 's/.*got: *\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | head -n1
}

if [ "$NEW_TAG" = "$CURRENT_TAG" ]; then
  # No version change, but still verify the committed src hash against what
  # the fetcher downloads today: GitHub regenerates archive tarballs in place
  # (same commit, different bytes), which silently breaks every build. While
  # the hash holds this is a store hit; when it drifted, the failed build's
  # "got:" line carries the hash to pin instead (self-heal).
  if OUT=$(nix build --no-link ".#cua-driver.src" 2>&1); then
    exit 0
  fi
  DRIFTED_HASH=$(printf '%s\n' "$OUT" | sed -n 's/.*got: *\(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | head -n1)
  [ -n "$DRIFTED_HASH" ] || {
    echo "cua-driver: src build failed without a hash mismatch:" >&2
    printf '%s\n' "$OUT" >&2
    exit 1
  }
  sed -i "s|$OLD_SRC_HASH|$DRIFTED_HASH|" "$DEFAULT_NIX"
  grep -q "hash = \"$DRIFTED_HASH\";" "$DEFAULT_NIX" ||
    { echo "cua-driver: src hash rewrite failed" >&2; exit 1; }
  echo "cua-driver: GitHub regenerated the $CURRENT_TAG archive; refreshed src hash -> $DRIFTED_HASH"
  cd "$REPO_ROOT"
  nix build --no-link ".#cua-driver"
  exit 0
fi

echo "cua-driver: $CURRENT_TAG -> $NEW_TAG"

# Prefetch everything before touching the file so a network failure cannot
# leave a new tag next to stale hashes.
SRC_HASH=$(fod_hash '
  let
    pkgs = (builtins.getFlake "'"$REPO_ROOT"'").inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  in
    pkgs.fetchFromGitHub {
      owner = "trycua";
      repo = "cua";
      tag = builtins.getEnv "NEW_TAG";
      hash = "'"$DUMMY_HASH"'";
    }')
[ -n "$SRC_HASH" ] || { echo "cua-driver: src hash echo failed for $NEW_TAG" >&2; exit 1; }

SKILLS_HASH=$(fod_hash '
  let
    pkgs = (builtins.getFlake "'"$REPO_ROOT"'").inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
  in
    pkgs.fetchurl {
      url = "https://github.com/trycua/cua/releases/download/${builtins.getEnv "NEW_TAG"}/${builtins.getEnv "NEW_TAG"}-skills.tar.gz";
      hash = "'"$DUMMY_HASH"'";
    }')
[ -n "$SKILLS_HASH" ] || { echo "cua-driver: skills hash echo failed for $NEW_TAG" >&2; exit 1; }

# Rewrite the tag; `version` is derived from it, so both URLs follow
# automatically.
sed -i "s|tag = \"$CURRENT_TAG\";|tag = \"$NEW_TAG\";|" "$DEFAULT_NIX"
grep -q "tag = \"$NEW_TAG\";" "$DEFAULT_NIX" || { echo "cua-driver: tag rewrite failed" >&2; exit 1; }

[ "$SRC_HASH" = "$OLD_SRC_HASH" ] || sed -i "s|$OLD_SRC_HASH|$SRC_HASH|" "$DEFAULT_NIX"
grep -q "hash = \"$SRC_HASH\";" "$DEFAULT_NIX" ||
  { echo "cua-driver: src hash rewrite failed" >&2; exit 1; }
[ "$SKILLS_HASH" = "$OLD_SKILLS_HASH" ] || sed -i "s|$OLD_SKILLS_HASH|$SKILLS_HASH|" "$DEFAULT_NIX"
grep -q "skillsHash = \"$SKILLS_HASH\";" "$DEFAULT_NIX" ||
  { echo "cua-driver: skills hash rewrite failed" >&2; exit 1; }

# Build once so a bad hash or a broken new release fails here instead of
# waiting for CI.
cd "$REPO_ROOT"
nix build --no-link ".#cua-driver"
