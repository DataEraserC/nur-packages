{
  lib,
  pkgs,
  stdenv,
  inputs ? null,
  fetchFromGitHub,
}:
let
  version = "0.3.2";
  src = fetchFromGitHub {
    owner = "lxzy-7";
    repo = "dsh-plugin-guard";
    rev = "v${version}";
    hash = "sha256-GO08IIRmUtrn5qyGUKZIh9YcsXa8zNA1xKjL5kVfGW8=";
  };
  buildDshPlugin =
    dshPkgs:
    dshPkgs.dsh.buildDshBundle (finalAttrs: {
      pname = "dsh-plugin-guard";
      inherit version src;

      npmDepsHash = "sha256-w0lU0iyO4MLXHatt3Cjbav85Hqq4IDm4sv8Vq/DdKKQ=";

      npmFlags = [ "--legacy-peer-deps" ];

      postPatch = ''
        cp ${./package.json} package.json
        cp ${./package-lock.json} package-lock.json
      '';

      dontNpmBuild = true;

      installPhase = ''
        runHook preInstall

        npmInstallHook

        mkdir -p $out/lib/node_modules/dsh-plugin-guard
        for item in *; do
          [ "$item" = "node_modules" ] && continue
          cp -r "$item" $out/lib/node_modules/dsh-plugin-guard/
        done

        # Create patched boot-guard in bin/ (upstream stays untouched)
        mkdir -p $out/bin
        cp scripts/boot-guard.sh $out/bin/boot-guard.sh
        substituteInPlace $out/bin/boot-guard.sh \
          --replace-quiet 'setsid "$dsh_cmd" web' 'setsid "$dsh_cmd" --profile "$PROFILE" "''${EXTRA_DSH_ARGS[@]}"'
        substituteInPlace $out/bin/boot-guard.sh \
          --replace-quiet 'PROFILE="''${PROFILE:-web}"' 'EXTRA_DSH_ARGS=(); PROFILE="''${PROFILE:-nix-web}"'
        substituteInPlace $out/bin/boot-guard.sh \
          --replace-quiet 'HARNESS_ROOT="''${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"' \
          'HARNESS_ROOT="''${HARNESS_ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}"'
        substituteInPlace $out/bin/boot-guard.sh \
          --replace-quiet 'CLI="$HARNESS_ROOT/node_modules/dsh-plugin-guard' \
          'CLI="$HARNESS_ROOT/lib/node_modules/dsh-plugin-guard'
        chmod +x $out/bin/boot-guard.sh

        runHook postInstall
      '';

      postInstall = ''
        test -f $out/lib/node_modules/dsh-plugin-guard/lib/client.js
      '';

      linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

      passthru = {
        aiProvenance = [
          {
            agent = "dsh";
            model = "mimo-v2.5-free";
            involvement = "authored";
          }
        ];
        updateScript = [ (toString ./update.sh) ];
      };

      meta = {
        description = "Install safety net for DeepSeek Harness: pre-install snapshots, one-click/automatic rollback, guarded boot, and incident reports that auto-trigger agent analysis";
        homepage = "https://github.com/lxzy-7/dsh-plugin-guard";
        license = lib.licenses.mit;
        maintainers = import ../maintainers.nix;
        mainProgram = "boot-guard.sh";
        platforms = lib.platforms.unix;
      };
    });
in
if inputs == null then
  stdenv.mkDerivation {
    pname = "dsh-plugin-guard";
    inherit version src;
    dontUnpack = true;
    buildPhase = "echo 'ERROR: dsh-plugin-guard requires the deepseek-harness flake input. Use: nix build .#dsh-plugin-guard' && exit 1";
    installPhase = "true";
  }
else
  buildDshPlugin (pkgs.extend inputs.deepseek-harness.overlays.default)
