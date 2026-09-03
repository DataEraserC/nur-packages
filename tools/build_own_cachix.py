#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3
import json
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


def candidates():
    out = subprocess.run(
        ["nix", "eval", "--json", f".#legacyPackages.{SYSTEM}", "--apply", EXPR],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(out.stdout)


def push_and_clean(attr, count):
    # attr is only used for the result symlink name
    results = ["./result"] + [f"./result-{i}" for i in range(2, count + 1)]
    subprocess.run(["cachix", "push", "dataeraserc"] + results, check=True)
    subprocess.run(["rm", "-rf"] + results, check=True)
    subprocess.run(["nix", "store", "gc"], check=True)


def main():
    names = candidates()
    print(f"found {len(names)} own packages")
    failed = []
    for a in names:
        print(f"=== building {a}")
        p = subprocess.run(["nix", "build", f".#{a}"])
        if p.returncode != 0:
            failed.append(a)
            subprocess.run(["rm", "-rf", "./result"], check=False)
            continue
        push_and_clean(a, 1)
    if failed:
        print(f"failed packages: {failed}", file=sys.stderr)
        sys.exit(1)
    print("done")


if __name__ == "__main__":
    main()
