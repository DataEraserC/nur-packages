#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p git
# shellcheck shell=bash
# dsh-cua-sandbox's nix version is inherited from the sibling cua-cli
# package, so it tracks the upstream cua-sdk-v* release on its own; the only
# literal to keep in sync is package.json's version.
#
# nix-update cannot drive this package at all: evaluated without the flake
# it throws ("requires the deepseek-harness flake input", which eval.nix
# surfaces as "expected a set but found null"), and even in --flake mode its
# src is the local bundle directory, which has no URL to fetch versions
# from. Compare the upstream tag list directly and exit 0 when package.json
# is already in sync.
set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
TAG_PREFIX="cua-sdk-v"
UPSTREAM="https://github.com/trycua/cua"

NEW_TAG=$(
  git ls-remote --tags "$UPSTREAM" |
    sed -n "s#.*refs/tags/\(${TAG_PREFIX}[0-9][0-9.]*\)\$#\1#p" |
    sort -V | tail -1
)
[ -n "$NEW_TAG" ] || { echo "dsh-cua-sandbox: no ${TAG_PREFIX}* tag upstream" >&2; exit 1; }
NEW_VERSION=${NEW_TAG#"$TAG_PREFIX"}

CURRENT_VERSION=$(
  sed -n 's/.*"version": "\([0-9][0-9.]*\)".*/\1/p' "$SCRIPT_DIR/package.json" | head -1
)
[ -n "$CURRENT_VERSION" ] || { echo "dsh-cua-sandbox: no version in package.json" >&2; exit 1; }

[ "$NEW_VERSION" = "$CURRENT_VERSION" ] && exit 0

sed -i "s/\"version\": \"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" "$SCRIPT_DIR/package.json"
grep -q "\"version\": \"$NEW_VERSION\"" "$SCRIPT_DIR/package.json" ||
  { echo "dsh-cua-sandbox: package.json version rewrite failed" >&2; exit 1; }
echo "dsh-cua-sandbox: package.json $CURRENT_VERSION -> $NEW_VERSION"
