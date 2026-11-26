_: {
  perSystem =
    _:
    let
      mkCICommand = pkgsAttr: ''
        tools/auto_build.py ${pkgsAttr} "$@"
      '';
    in
    {
      commands = rec {
        ci = mkCICommand "ciPackages";
        ci-cuda = mkCICommand "ciPackagesWithCuda";

        # Run passthru.updateScript-based updates (migrated packages).
        # Accepts the same arguments as tools/update-package.
        update-pkg = ''
          set -euo pipefail
          ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo .)
          "$ROOT"/tools/update-package "$@"
        '';

        nur-check = ''
          set -euo pipefail
          TMPDIR=$(mktemp -d)
          FLAKEDIR=$(pwd)

          git clone --depth=1 https://github.com/nix-community/NUR.git "$TMPDIR"
          cd "$TMPDIR/ci"
          nix flake update
          cd "$TMPDIR"
          sed -i "s/-p python3 /-p python311 /g" "$TMPDIR/bin/nur"

          cp ${../../repos.json} repos.json
          rm -f repos.json.lock

          bin/nur update
          bin/nur eval "$FLAKEDIR"

          git clone --single-branch "https://github.com/nix-community/nur-combined.git"
          cp repos.json repos.json.lock nur-combined/
          bin/nur index nur-combined > index.json

          cd "$FLAKEDIR"
          rm -rf "$TMPDIR"
        '';

        readme = ''
          set -uo pipefail
          nix build --show-trace .#_meta.readme
          cat result > README.md
        '';

        trace = ''
          rm -rf trace.txt*
          strace -ff --trace=%file -o trace.txt "$@"
        '';

        update = ''
          set -uo pipefail
          export LANG=en_US.UTF-8
          # The own-package list and every update script resolve <nixpkgs>;
          # pin it to the freshly locked tree rather than the runner's
          # ambient channel.
          nix flake update
          export NIX_PATH=nixpkgs=$(nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.outPath')
          STATUS=0
          # Only downstream-maintained ("own") packages are auto-updated.
          # The rules live in helpers/own-packages.nix, shared with
          # tools/build_own_cachix.py and tools/update-package --own;
          # upstream packages follow upstream merges instead.
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
          ${readme}
          exit $STATUS
        '';

        # List downstream-maintained package attrPaths, one per line
        # (rules: helpers/own-packages.nix).
        own-packages = ''
          set -euo pipefail
          export NIX_PATH=nixpkgs=$(nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.outPath')
          LIST=$(nix-build --no-out-link helpers/own-packages-list.nix \
            --arg inputs '(builtins.getFlake (toString ./.)).inputs')
          cat "$LIST"
        '';
      };
    };
}
