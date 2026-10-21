#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash -p cacert -p curl -p git -p jq -p nodejs_24 -p nix -p nix-update -p patch -p prefetch-npm-deps -p python3
# shellcheck shell=bash
set -euo pipefail

# LobsterAI publishes source only: no tag carries a package-lock.json, so the
# lockfiles in this directory are generated here and are tied to the version.
# This script owns that cycle end to end - version, src hash, the four npm
# lockfiles and the fetchNpmDeps hashes they feed (the embedded openclaw
# runtime reuses the app lockfile, so its hash moves with them).

DIR=$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)
# nix-update --flake resolves the flake from the working directory, so it has to
# run from the repo root or it writes the version into $DIR/pkgs/<group>/<pkg>.
ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$DIR/../../..")
ATTR=${UPDATE_NIX_ATTR_PATH:-uncategorized-DataEraserC.lobsterai-unwrapped}
# The flake output flattens package groups, so build with the bare name.
FLAT=${ATTR##*.}
SKILLS=(web-search imap-smtp-email pptx)
TAG_RE='^[0-9]{4}\.[0-9]{1,2}\.[0-9]{1,2}$'

die() {
  printf 'lobsterai: %s\n' "$*" >&2
  exit 1
}

# Releases moved from v0.x.y tags to date tags (2026.10.16); only the date form
# is a build target. Numeric sort keeps 2026.10.2 below 2026.10.16.
latest_tag() {
  git ls-remote --tags --refs https://github.com/netease-youdao/LobsterAI |
    sed -n 's#.*refs/tags/\(.*\)$#\1#p' |
    grep -E "$TAG_RE" |
    sort -t. -k1,1n -k2,2n -k3,3n |
    tail -n1
}

old_version=$(sed -n 's/^  version = "\([^"]*\)";$/\1/p' "$DIR/default.nix")
[ -n "$old_version" ] || die "cannot read version from default.nix"

new_version=$(latest_tag)
[ -n "$new_version" ] || die "cannot read the tag list from GitHub"

# A run that dies after nix-update, e.g. on a network flake while regenerating
# the lockfiles, leaves the new version behind with stale hashes. The version
# alone cannot tell that apart from a finished update, so the early exit also
# builds what the version is supposed to guarantee; on a finished tree those
# four fixed-output builds come from the store, and when they fail the tree is
# incomplete and the run falls through and redoes the regeneration.
deps_ok() {
  for attr in npmDeps skillWebSearch.npmDeps skillEmail.npmDeps skillPptx.npmDeps; do
    nix build --no-link ".#$FLAT.$attr" >/dev/null 2>&1 || return 1
  done
}

if [ "$new_version" = "$old_version" ] && (cd "$ROOT" && deps_ok); then
  echo "lobsterai: already at $old_version"
  exit 0
fi
if [ "$new_version" = "$old_version" ]; then
  echo "lobsterai: $old_version is incomplete, redoing its lockfiles and hashes"
else
  echo "lobsterai: $old_version -> $new_version"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

curl -fsSL -o "$work/src.tar.gz" \
  "https://github.com/netease-youdao/LobsterAI/archive/refs/tags/$new_version.tar.gz"
tar -xzf "$work/src.tar.gz" -C "$work" --strip-components=1

# The embedded openclaw runtime is a second upstream with its own src, pnpm
# deps and npm deps, pinned by the LobsterAI tag. Bumping it needs its own pass
# over openclaw-runtime.nix and the cfmind lockfile pair, so refuse to produce a
# tree whose runtime silently lags the app.
openclaw_pin=$(jq -r '.openclaw.version // ""' "$work/package.json")
openclaw_here=v$(sed -n 's/^  version = "\([^"]*\)";$/\1/p' "$DIR/openclaw-runtime.nix")
[ "$openclaw_pin" = "$openclaw_here" ] ||
  die "$new_version pins openclaw ${openclaw_pin:-unknown}, openclaw-runtime.nix has $openclaw_here: bump that package first"

for skill in "${SKILLS[@]}"; do
  [ -f "$work/SKILLs/$skill/package.json" ] ||
    die "$new_version no longer ships SKILLs/$skill: drop it from mkSkill here"
done

# Applied with --forward at build time, so a reworded upstream script breaks the
# build rather than this script only after the version is already rewritten.
patch -p1 --dry-run --batch --forward --no-backup-if-mismatch -d "$work" \
  <"$DIR/openclaw-runtime-offline.patch" >/dev/null ||
  die "openclaw-runtime-offline.patch no longer applies to $new_version"

(cd "$ROOT" && nix-update "$FLAT" --version "$new_version" --src-only --flake)

# Seed npm with the committed lockfile: it only re-resolves the ranges the new
# package.json forces, so a bump does not drag unrelated transitive updates (and
# the patch-package patches that pin their own versions) along with it.
regenerate() {
  cp "$2" "$1/package-lock.json"
  (cd "$1" && npm install --ignore-scripts --no-audit --no-fund --loglevel=error) ||
    die "npm install failed for $1"
  cp "$1/package-lock.json" "$2"
  # prefetch-npm-deps hashes the lockfile bytes, so a missing final newline
  # would produce a hash that does not match the committed file.
  [ -z "$(tail -c1 "$2")" ] || die "$2 does not end with a newline"
}

regenerate "$work" "$DIR/package-lock.json"
for skill in "${SKILLS[@]}"; do
  regenerate "$work/SKILLs/$skill" "$DIR/skills/$skill/package-lock.json"
done

app_hash=$(prefetch-npm-deps "$DIR/package-lock.json")
web_hash=$(prefetch-npm-deps "$DIR/skills/web-search/package-lock.json")
email_hash=$(prefetch-npm-deps "$DIR/skills/imap-smtp-email/package-lock.json")
pptx_hash=$(prefetch-npm-deps "$DIR/skills/pptx/package-lock.json")

python3 - "$DIR" "$app_hash" "$web_hash" "$email_hash" "$pptx_hash" <<'PY'
import re
import sys

directory, app, web, email, pptx = sys.argv[1:]


def rehash(path, blocks):
    text = open(path).read()
    for marker, new_hash in blocks:
        start = text.find(marker)
        if start < 0 or text.find(marker, start + 1) >= 0:
            sys.exit(f"{path}: {marker!r} must appear exactly once")
        match = re.compile(r'hash = "sha256-[^"]*";').search(text, start)
        if match is None:
            sys.exit(f"{path}: no hash after {marker!r}")
        text = text[: match.start()] + f'hash = "{new_hash}";' + text[match.end() :]
    open(path, "w").write(text)


rehash(
    f"{directory}/default.nix",
    [
        ("skillWebSearch = mkSkill {", web),
        ("skillEmail = mkSkill {", email),
        ("skillPptx = mkSkill {", pptx),
        ("appDeps = fetchNpmDeps {", app),
    ],
)
# The runtime rebuilds the app dependency tree from the same lockfile.
rehash(f"{directory}/openclaw-runtime.nix", [("appDeps = fetchNpmDeps {", app)])
PY

for attr in npmDeps skillWebSearch.npmDeps skillEmail.npmDeps skillPptx.npmDeps; do
  echo "lobsterai: verifying .#$FLAT.$attr"
  (cd "$ROOT" && nix build --no-link ".#$FLAT.$attr")
done

echo "lobsterai: $new_version ready, run 'nix build .#$FLAT' before committing"
