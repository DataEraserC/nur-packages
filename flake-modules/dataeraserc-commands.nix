{ lib, ... }:
{
  perSystem = _: {
    # Downstream fork: the scheduled auto-update only bumps packages this
    # fork maintains. Override the upstream `update` command here instead
    # of editing flake-modules/_internal/commands.nix, so upstream merges
    # do not conflict on it. Own-package rules: helpers/own-packages.nix
    # (shared with tools/build_own_cachix.py and tools/update-package --own).
    commands.update = lib.mkForce ''
      set -uo pipefail
      export LANG=en_US.UTF-8
      # The own-package list and every update script resolve <nixpkgs>;
      # pin it to the freshly locked tree rather than the runner's
      # ambient channel.
      nix flake update
      export NIX_PATH=nixpkgs=$(nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.outPath')
      STATUS=0
      OWN_LIST=$(nix-build --no-out-link helpers/own-packages-list.nix \
        --arg inputs '(builtins.getFlake (toString ./.)).inputs') || STATUS=1
      while IFS= read -r A; do
        D="pkgs/''${A//.//}"
        for F in $(command find "$D" -name 'update-standalone.*' -type f 2>/dev/null); do
          echo "Executing $F"
          chmod +x "$F"
          "$F" || STATUS=1
        done
      done <"$OWN_LIST"
      ./tools/update-package --own || STATUS=1
      # Regenerate README even when individual updates failed
      set -uo pipefail
      nix build --show-trace .#_meta.readme
      cat result > README.md

      exit $STATUS
    '';

    # List downstream-maintained package attrPaths, one per line.
    commands.own-packages = ''
      set -euo pipefail
      export NIX_PATH=nixpkgs=$(nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.outPath')
      LIST=$(nix-build --no-out-link helpers/own-packages-list.nix \
        --arg inputs '(builtins.getFlake (toString ./.)).inputs')
      cat "$LIST"
    '';
  };
}
