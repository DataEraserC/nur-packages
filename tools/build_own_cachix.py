#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
import json
import os
import subprocess
import sys

EXPR = """
x: builtins.filter
  (n:
    let
      d = x.${n};
      pos = (d.meta.position or "");
    in
    (builtins.tryEval d).success
    && (d ? drvPath)
    && !(d.meta.broken or false)
    && ((d.meta.platforms or [ ]) == [ ] || builtins.elem "x86_64-linux" d.meta.platforms)
    && (builtins.match ".*/pkgs/uncategorized-DataEraserC/.*" pos != null
        || builtins.match ".*/pkgs/kernel-modules/aw88399-legion.*" pos != null)
  )
  (builtins.attrNames x)
"""

SYSTEM = "x86_64-linux"
DEFAULT_BATCH_SIZE = 2


def candidates():
    out = subprocess.run(
        ["nix", "eval", "--json", f".#legacyPackages.{SYSTEM}", "--apply", EXPR],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(out.stdout)


def result_paths(count):
    return ["./result"] + [f"./result-{i}" for i in range(2, count + 1)]


def cleanup_results(count):
    # nix build leaves ./result, ./result-2, ... symlinks; drop any stale ones
    subprocess.run(["rm", "-rf"] + result_paths(count), check=False)


def push_and_clean(count):
    subprocess.run(["cachix", "push", "dataeraserc"] + result_paths(count), check=True)
    cleanup_results(count)
    subprocess.run(["nix", "store", "gc"], check=True)


def build_batch(attrs, failed):
    if not attrs:
        return
    count = len(attrs)
    print(f"=== batch ({count}): {' '.join(attrs)}")
    cleanup_results(count)
    p = subprocess.run(["nix", "build"] + [f".#{a}" for a in attrs])
    if p.returncode == 0:
        push_and_clean(count)
        return

    # One or more packages in the batch failed. Retry individually so a single
    # failure does not drop the successful packages of this batch.
    cleanup_results(count)
    for a in attrs:
        print(f"=== retrying individually: {a}")
        p = subprocess.run(["nix", "build", f".#{a}"])
        if p.returncode != 0:
            failed.append(a)
            cleanup_results(1)
            continue
        push_and_clean(1)


def main():
    batch_size = int(os.environ.get("BATCH_SIZE", str(DEFAULT_BATCH_SIZE)))
    if batch_size < 1:
        batch_size = DEFAULT_BATCH_SIZE
    names = candidates()
    print(f"found {len(names)} own packages, batch size {batch_size}")
    failed = []
    for i in range(0, len(names), batch_size):
        build_batch(names[i : i + batch_size], failed)
    if failed:
        print(f"failed packages: {failed}", file=sys.stderr)
        sys.exit(1)
    print("done")


if __name__ == "__main__":
    main()
