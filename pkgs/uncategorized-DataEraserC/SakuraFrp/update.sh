#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl -p nix -p python3
# shellcheck shell=bash
set -euo pipefail

FILE="$(dirname "$(readlink -f "$0")")/SakuraFrp.nix"
# The mirror is unreachable from non-CN networks on and off (Cloudflare 521,
# 429 rate limiting, transfers truncated mid-body). An unreachable index means
# nothing can be checked this run, so warn and leave the file alone instead of
# turning the weekly run red; an index that answers but no longer parses is a
# real upstream change and must fail.
INDEX=$(curl -fsSL --retry 3 --retry-delay 2 --retry-all-errors --connect-timeout 20 --max-time 120 \
  'https://nya.globalslb.net/natfrp/client/launcher-unix/' 2>/dev/null) || INDEX=""
if [ -z "$INDEX" ]; then
  echo "SakuraFrp: warning: upstream index unreachable, skipping this run" >&2
  exit 0
fi
NEW_VERSION=$(printf '%s\n' "$INDEX" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n1)
[ -n "$NEW_VERSION" ] || {
  echo "Failed to detect new version" >&2
  exit 1
}
export NEW_VERSION
set +e
python3 - "$FILE" <<'PYEOF'
import json
import os
import re
import subprocess
import sys
import time

path = sys.argv[1]
text = open(path).read()
old = re.search(r'^  version = "([^"]+)";', text, re.M).group(1)
new = os.environ["NEW_VERSION"]
version_changed = old != new
if not version_changed:
    print(f"SakuraFrp already at {new}; re-prefetching to detect re-published content")

block_re = re.compile(
    r'url = "(https://nya\.globalslb\.net/natfrp/client/launcher-unix/[^"]+)";\n(\s*)hash = "[^"]*";'
)

# Upstream republishes tarballs under the same URLs, so every pinned hash is
# re-verified on each run. The mirror behind Cloudflare is however routinely
# unreachable from non-CN networks: it answers 521 when its edge cannot reach
# the origin, and truncates large bodies mid-transfer. Both make prefetch fail
# without saying anything about the hashes, so retry, then separate "file is
# gone" (always fatal) from "transport broke" (fatal only on a version bump,
# otherwise a skipped verification must not turn every weekly run red).
ATTEMPTS = 3


def prefetch(url):
    error = ""
    for attempt in range(1, ATTEMPTS + 1):
        proc = subprocess.run(
            ["nix", "store", "prefetch-file", "--json", url],
            capture_output=True,
            text=True,
        )
        if proc.returncode == 0:
            return json.loads(proc.stdout)["hash"]
        error = (proc.stderr or proc.stdout).strip()
        print(f"prefetch attempt {attempt}/{ATTEMPTS} failed: {url}\n  {error}", file=sys.stderr)
        if attempt < ATTEMPTS:
            time.sleep(5 * attempt)
    return error


hashes = {}
failures = []
for match in block_re.finditer(text):
    url = match.group(1).replace("${version}", new)
    result = prefetch(url)
    if result.startswith("sha256-"):
        hashes[url] = result
    else:
        failures.append((url, result))

if failures:
    for url, error in failures:
        print(f"failed to prefetch {url}: {error}", file=sys.stderr)
    if version_changed:
        print("SakuraFrp: aborting the version bump, hashes could not be computed", file=sys.stderr)
        sys.exit(1)
    if any(re.search(r"HTTP error (404|410)\b", error) for _, error in failures):
        print("SakuraFrp: pinned tarball is gone upstream, hashes must be re-pinned", file=sys.stderr)
        sys.exit(1)
    print(
        f"SakuraFrp: warning: hash re-verification skipped, upstream mirror unreachable "
        f"(still at {new}); nothing written",
        file=sys.stderr,
    )
    sys.exit(3)

text = text.replace(f'version = "{old}";', f'version = "{new}";')


def repl(m):
    url = m.group(1).replace("${version}", new)
    return f'url = "{m.group(1)}";\n{m.group(2)}hash = "{hashes[url]}";'


text, n = block_re.subn(repl, text)
open(path, "w").write(text)
print(f"SakuraFrp updated to {new} ({n} hashes)")
PYEOF
rc=$?
set -e
if [ "$rc" -eq 3 ]; then
  echo "SakuraFrp: skipped (upstream unreachable, no local changes to verify)"
  exit 0
elif [ "$rc" -ne 0 ]; then
  exit "$rc"
fi

# Real build verification so hash/version mistakes fail here, not in CI
# (repo rule: hash-writing update scripts must build-verify their output).
echo "Build test: nix build .#SakuraFrp"
nix build --no-link ".#SakuraFrp"
