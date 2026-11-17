#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p git
# shellcheck shell=bash
# dsh-cua-driver's nix version is inherited from the sibling cua-driver
# package, so it tracks the upstream cua-driver-rs-v* release on its own;
# the only literal to keep in sync is package.json's version.
#
# nix-update cannot drive this package at all: evaluated without the flake
# it throws ("requires the deepseek-harness flake input", which eval.nix
# surfaces as "expected a set but found null"), and even in --flake mode its
# src is the local bundle directory, which has no URL to fetch versions
# from. Compare the upstream tag list directly and exit 0 when package.json
# is already in sync.
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TAG_PREFIX="cua-driver-rs-v"

# Follow the sibling rather than the upstream tag list. This bundle's nix
# version is inherited from cua-driver, so package.json must track whatever
# cua-driver is actually pinned to: when that package's own update fails and
# rolls back (a network failure fetching a release asset, say), following
# upstream here would bump package.json anyway and leave the two disagreeing.
SIBLING="$SCRIPT_DIR/../cua-driver/default.nix"
[ -f "$SIBLING" ] || {
  echo "dsh-cua-driver: cannot find $SIBLING" >&2
  exit 1
}
SIBLING_TAG=$(
  sed -n "s/^ *tag = \"\(${TAG_PREFIX}[0-9][0-9.]*\)\";/\1/p" "$SIBLING" | head -1
)
[ -n "$SIBLING_TAG" ] ||
  {
    echo "dsh-cua-driver: no tag in $SIBLING" >&2
    exit 1
  }
NEW_TAG=$SIBLING_TAG
NEW_VERSION=${NEW_TAG#"$TAG_PREFIX"}

CURRENT_VERSION=$(
  sed -n 's/.*"version": "\([0-9][0-9.]*\)".*/\1/p' "$SCRIPT_DIR/package.json" | head -1
)
[ -n "$CURRENT_VERSION" ] || {
  echo "dsh-cua-driver: no version in package.json" >&2
  exit 1
}

[ "$NEW_VERSION" = "$CURRENT_VERSION" ] && exit 0

sed -i "s/\"version\": \"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" "$SCRIPT_DIR/package.json"
grep -q "\"version\": \"$NEW_VERSION\"" "$SCRIPT_DIR/package.json" ||
  {
    echo "dsh-cua-driver: package.json version rewrite failed" >&2
    exit 1
  }
echo "dsh-cua-driver: package.json $CURRENT_VERSION -> $NEW_VERSION"
