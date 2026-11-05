#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p curl -p nix-update
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
PACKAGE_FILE="$SCRIPT_DIR/default.nix"

echo "Updating new-api..."

# Detect latest release tag from atom feed
FEED=$(curl -fsSL "https://github.com/QuantumNous/new-api/releases.atom") || true
LATEST_TAG=$(grep -oP '<id>tag:github.com,2008:Repository/[0-9]+/\Kv[0-9][^<]+' <<<"$FEED" |
  head -1) || true

if [ -z "$LATEST_TAG" ]; then
  LATEST_TAG=$(git ls-remote --tags https://github.com/QuantumNous/new-api |
    sed -n 's#.*refs/tags/v\([0-9].*\)$#v\1#p' |
    grep -v '\^{}' |
    sort -V | tail -1)
fi

NEW_VERSION="${LATEST_TAG#v}"
OLD_VERSION="${UPDATE_NIX_OLD_VERSION:-}"

echo "Latest upstream tag: $LATEST_TAG (version: $NEW_VERSION)"
echo "Current version:     $OLD_VERSION"

if [ "$NEW_VERSION" = "$OLD_VERSION" ]; then
  echo "Already up to date."
  exit 0
fi

# Step 1: nix-update handles version, src hash, and vendorHash
echo "Updating to $NEW_VERSION..."
nix-update "$UPDATE_NIX_ATTR_PATH" --version "$NEW_VERSION"

# Step 2: recompute the webDeps FOD hash on a throwaway copy.
#
# The real default.nix is never modified until the hash is known: a failed or
# killed probe must not leave lib.fakeHash behind, because the auto-update
# workflow commits the working tree even when an update script fails
# (bd04579e did exactly that and broke the new-api build).
PROBE_ROOT=$(mktemp -d)
PROBE_DIR="$PROBE_ROOT/pkg"
PROBE_FILE="$PROBE_DIR/default.nix"
PROBE_LOG="$PROBE_ROOT/build.log"
FINAL_FILE=""

cleanup() {
  rm -rf "$PROBE_ROOT"
  if [ -n "$FINAL_FILE" ]; then
    rm -f "$FINAL_FILE"
  fi
}
trap cleanup EXIT

mkdir -p "$PROBE_DIR"
cp "$PACKAGE_FILE" "$PROBE_FILE"
# The package imports ../maintainers.nix, which resolves to PROBE_ROOT.
cp "$SCRIPT_DIR/../maintainers.nix" "$PROBE_ROOT/maintainers.nix"
sed -E 's#outputHash = ("sha256-[^"]*"|lib[.]fakeHash)#outputHash = lib.fakeHash#' "$PROBE_FILE" >"$PROBE_FILE.tmp"
mv "$PROBE_FILE.tmp" "$PROBE_FILE"

SYSTEM=$(nix eval --impure --raw --expr 'builtins.currentSystem')
PROBE_EXPR="let f = builtins.getFlake \"path:${REPO_ROOT}\"; pkgs = f.inputs.nixpkgs.legacyPackages.${SYSTEM}; in pkgs.callPackage ${PROBE_FILE} { }"

# The probe build is expected to fail with a hash mismatch; that error is the
# only place Nix reports the real hash. Any other failure yields no hash and
# the script exits without touching default.nix.
if nix build --impure --no-link --print-out-paths --expr "$PROBE_EXPR" >"$PROBE_LOG" 2>&1; then
  echo "ERROR: the placeholder probe build unexpectedly succeeded." >&2
  tail -20 "$PROBE_LOG" >&2
  exit 1
fi

# Pick the mismatch block that belongs to new-api-web-deps, so a failing
# vendorHash (or any other FOD) can never be mistaken for this one.
WEB_DEPS_HASH=$(
  awk '
    /hash mismatch in fixed-output derivation/ {
      block = $0
      for (i = 0; i < 3; i++) { if ((getline line) <= 0) break; block = block "\n" line }
    }
    block ~ /new-api-web-deps/ && block ~ /got:/ {
      if (match(block, /got:[[:space:]]+sha256-[A-Za-z0-9\/+=]+/)) {
        hash = substr(block, RSTART + 4, RLENGTH - 4)
        gsub(/[[:space:]]/, "", hash)
        print hash
        exit
      }
    }
  ' "$PROBE_LOG"
) || true

if [ -z "$WEB_DEPS_HASH" ]; then
  echo "ERROR: could not determine the new-api-web-deps FOD hash." >&2
  echo "default.nix was left untouched; rerun once the probe build works." >&2
  tail -20 "$PROBE_LOG" >&2
  exit 1
fi

# Step 3: write the new hash into a copy next to default.nix and rename it into
# place. Same-directory rename is atomic, so the file is either the old content
# or the finished new content, never a half-written one.
FINAL_FILE=$(mktemp "$SCRIPT_DIR/.default.nix.XXXXXX")
sed -E "s#outputHash = (\"sha256-[^\"]*\"|lib[.]fakeHash)#outputHash = \"$WEB_DEPS_HASH\"#" "$PACKAGE_FILE" >"$FINAL_FILE"
if ! grep -q "outputHash = \"$WEB_DEPS_HASH\"" "$FINAL_FILE"; then
  echo "ERROR: the outputHash line could not be rewritten; default.nix is untouched." >&2
  exit 1
fi
chmod --reference="$PACKAGE_FILE" "$FINAL_FILE"
mv "$FINAL_FILE" "$PACKAGE_FILE"
FINAL_FILE=""

echo "webDeps hash updated: $WEB_DEPS_HASH"
echo "Done! Version: $NEW_VERSION"
