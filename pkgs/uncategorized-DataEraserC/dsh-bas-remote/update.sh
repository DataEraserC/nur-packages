#!/usr/bin/env bash
set -euo pipefail

DIR="$(dirname "$(readlink -f "$0")")"
FILE="$DIR/default.nix"
REPO="DataEraserC/dsh-bas-remote"

# 1. get latest tag from GitHub
TAG=$(curl -fsSL "https://api.github.com/repos/$REPO/tags" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['name'])")
LATEST="${TAG#v}" # strip 'v' prefix for version comparison
echo "latest tag: $TAG (version: $LATEST)"

# 2. extract current version from default.nix
CURRENT=$(grep -oP 'version = "\K[^"]+' "$FILE")
echo "current version: $CURRENT"

if [ "$LATEST" = "$CURRENT" ]; then
  echo "already up to date"
  exit 0
fi

# 3. prefetch source tarball
URL="https://github.com/$REPO/archive/$TAG.tar.gz"
echo "fetching $URL ..."
HASH=$(nix store prefetch-file --json --unpack "$URL" | python3 -c "import sys,json; print(json.load(sys.stdin)['hash'])")
echo "src hash: $HASH"

# 4. extract old npmDepsHash from default.nix
OLD_NPM_HASH=$(grep -oP 'npmDepsHash = "\K[^"]+' "$FILE")
echo "old npmDepsHash: $OLD_NPM_HASH"

# 5. try to compute new npmDepsHash
TMPDIR=$(mktemp -d)
curl -fsSL "$URL" | tar xz -C "$TMPDIR" --strip-components=1
cd "$TMPDIR"
npm install --package-lock-only --legacy-peer-deps --no-audit --no-fund --ignore-scripts 2>/dev/null || true

NEW_NPM_HASH="$OLD_NPM_HASH"
if command -v prefetch-npm-deps &>/dev/null && [ -f package-lock.json ]; then
  NEW_NPM_HASH=$(prefetch-npm-deps package-lock.json 2>/dev/null || echo "$OLD_NPM_HASH")
  echo "new npmDepsHash: $NEW_NPM_HASH"
else
  echo "prefetch-npm-deps not available, keeping existing npmDepsHash"
fi
cd /
rm -rf "$TMPDIR"

# 6. update default.nix
python3 - "$FILE" "$LATEST" "$HASH" "$CURRENT" "$NEW_NPM_HASH" "$OLD_NPM_HASH" <<'PYEOF'
import re, sys
path, version, src_hash, old_version, new_npm_hash, old_npm_hash = sys.argv[1:]
content = open(path).read()
content = content.replace(f'version = "{old_version}"', f'version = "{version}"')
content = re.sub(r'hash = "sha256-[^"]+"', f'hash = "{src_hash}"', content, count=1)
if new_npm_hash != old_npm_hash:
    content = content.replace(f'npmDepsHash = "{old_npm_hash}"', f'npmDepsHash = "{new_npm_hash}"')
    print(f"npmDepsHash updated: {old_npm_hash[:20]}... -> {new_npm_hash[:20]}...")
else:
    print("npmDepsHash unchanged")
open(path, 'w').write(content)
print(f"updated {old_version} -> {version}")
PYEOF

echo "done. Run 'nix build' to verify, then commit."
