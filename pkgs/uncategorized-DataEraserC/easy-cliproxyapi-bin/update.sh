#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p git -p nix -p curl
# shellcheck shell=bash
# EasyCLIProxyAPI publishes the GitHub release (releases.atom entry) before its
# assets finish uploading: on 2026-11-16 the v0.3.108 entry was already served
# at 08:22:24Z while EasyCLIProxyAPI-v0.3.108-Linux-amd64.tar.gz only became
# downloadable at 08:36:29Z, and the scheduled run read the feed at 08:34:58Z.
# nix-update trusts that feed, prefetches the asset seconds later, gets a 404
# (its own 4 retries span ~7 s) and dies with
#   UpdateError: failed to retrieve hash ... easy-cliproxyapi-bin.src
# after having already rewritten `version` in default.nix -- which is how the
# stale-hash file got committed. So drive the version from the release *listing*
# and only touch default.nix once the asset really answers.
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../../.." && pwd)
DEFAULT_NIX="$SCRIPT_DIR/default.nix"
UPSTREAM="https://github.com/router-for-me/EasyCLIProxyAPI"
ASSET_NAME="EasyCLIProxyAPI-v%s-Linux-amd64.tar.gz"

# The release feed and the asset upload land minutes apart, so each attempt is
# given a generous budget: 6 attempts with a 60 s backoff covers ~15 min, far
# more than the observed 14-minute gap, and still finishes inside the runner's
# per-package timeout (UPDATE_PACKAGE_TIMEOUT, 900 s by default).
ATTEMPTS=6
DELAY=60

CURRENT_VERSION=$(
  sed -n 's/^[[:space:]]*version = "\([0-9][0-9.]*\)";.*/\1/p' "$DEFAULT_NIX" | head -1
)
[ -n "$CURRENT_VERSION" ] || {
  echo "easy-cliproxyapi-bin: no version literal in $DEFAULT_NIX" >&2
  exit 1
}

# Latest release tag, newest first. releases.atom lists tags; the download URL
# needs the tag exactly as published (v-prefixed).
NEW_VERSION=$(
  curl -fsSL --retry 3 --retry-delay 5 --retry-all-errors \
    "$UPSTREAM/releases.atom" |
    sed -n 's#.*releases/tag/v\([0-9][0-9.]*\)".*#\1#p' |
    sort -V | tail -1
)
[ -n "$NEW_VERSION" ] || {
  echo "easy-cliproxyapi-bin: no release tag in $UPSTREAM/releases.atom" >&2
  exit 1
}

if [ "$NEW_VERSION" = "$CURRENT_VERSION" ]; then
  exit 0
fi

echo "easy-cliproxyapi-bin: $CURRENT_VERSION -> $NEW_VERSION"

ASSET_URL=$(printf "$UPSTREAM/releases/download/v$NEW_VERSION/$ASSET_NAME" "$NEW_VERSION")

# Wait for the asset itself before reading the version: a 404 here means the
# release exists but its binaries are still uploading, not that the release is
# broken.
fetchable() {
  local attempt
  for attempt in $(seq 1 "$ATTEMPTS"); do
    if curl -fsSI -o /dev/null -L "$1" 2>/dev/null; then
      return 0
    fi
    echo "easy-cliproxyapi-bin: attempt $attempt/$ATTEMPTS: $1 not available yet" >&2
    if [ "$attempt" -lt "$ATTEMPTS" ]; then sleep "$DELAY"; fi
  done
  return 1
}

prefetch() {
  local attempt out
  for attempt in $(seq 1 "$ATTEMPTS"); do
    if out=$(nix store prefetch-file --json "$1" 2>/dev/null); then
      printf '%s\n' "$out" | sed -n 's/.*"hash":"\(sha256-[^"]*\)".*/\1/p'
      return 0
    fi
    echo "easy-cliproxyapi-bin: prefetch attempt $attempt/$ATTEMPTS failed: $1" >&2
    if [ "$attempt" -lt "$ATTEMPTS" ]; then sleep "$DELAY"; fi
  done
  return 1
}

if ! fetchable "$ASSET_URL"; then
  echo "easy-cliproxyapi-bin: $ASSET_URL never became downloadable; keeping $CURRENT_VERSION" >&2
  exit 1
fi

OLD_HASH=$(
  sed -n 's/^[[:space:]]*hash = "\(sha256-[^"]*\)";.*/\1/p' "$DEFAULT_NIX" | head -1
)
[ -n "$OLD_HASH" ] || {
  echo "easy-cliproxyapi-bin: no hash literal in $DEFAULT_NIX" >&2
  exit 1
}

# Prefetch before touching the file, so a network failure cannot leave a new
# version next to a stale hash (the failure mode this script exists to avoid).
NEW_HASH=$(prefetch "$ASSET_URL") || NEW_HASH=""
[ -n "$NEW_HASH" ] || {
  echo "easy-cliproxyapi-bin: cannot read the hash of $ASSET_URL" >&2
  exit 1
}

sed -i "s|version = \"$CURRENT_VERSION\";|version = \"$NEW_VERSION\";|" "$DEFAULT_NIX"
grep -q "version = \"$NEW_VERSION\";" "$DEFAULT_NIX" || {
  echo "easy-cliproxyapi-bin: version rewrite failed" >&2
  exit 1
}

if [ "$NEW_HASH" != "$OLD_HASH" ]; then
  sed -i "s|$OLD_HASH|$NEW_HASH|" "$DEFAULT_NIX"
fi
grep -q "hash = \"$NEW_HASH\";" "$DEFAULT_NIX" || {
  echo "easy-cliproxyapi-bin: hash rewrite failed" >&2
  exit 1
}

# Build once so a bad hash or an unusable asset fails here, not in the run that
# commits.
cd "$REPO_ROOT"
nix build --no-link ".#easy-cliproxyapi-bin"
