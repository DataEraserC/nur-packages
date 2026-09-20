{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  nix-update-script,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-plugin-guard requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-plugin-guard)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-plugin-guard";
    version = "0.3.2";

    src = fetchFromGitHub {
      owner = "lxzy-7";
      repo = "dsh-plugin-guard";
      rev = "v${finalAttrs.version}";
      hash = "sha256-GO08IIRmUtrn5qyGUKZIh9YcsXa8zNA1xKjL5kVfGW8=";
    };

    npmDepsHash = "sha256-3ejcnV7OaOJCBiAmSHMZWiwSpctja2udmDQO9BoMrq0=";

    forceEmptyCache = true;

    npmFlags = [ "--legacy-peer-deps" ];

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/dsh-plugin-guard
      cp -r . $out/lib/node_modules/dsh-plugin-guard/

      # Create patched boot-guard in bin/ (upstream stays untouched)
      mkdir -p $out/bin
      cp scripts/boot-guard.sh $out/bin/boot-guard.sh
      substituteInPlace $out/bin/boot-guard.sh \
        --replace-quiet 'setsid "$dsh_cmd" web' 'setsid "$dsh_cmd" --profile "$PROFILE" $EXTRA_DSH_ARGS'
      substituteInPlace $out/bin/boot-guard.sh \
        --replace-quiet 'PROFILE="''${PROFILE:-web}"' 'PROFILE="''${PROFILE:-nix-web}"'
      substituteInPlace $out/bin/boot-guard.sh \
        --replace-quiet 'HARNESS_ROOT="''${HARNESS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"' \
        'HARNESS_ROOT="''${HARNESS_ROOT:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}"'
      chmod +x $out/bin/boot-guard.sh

      runHook postInstall
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-plugin-guard/lib/client.js
    '';

    passthru = {
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.5-free";
          involvement = "authored";
        }
      ];
      updateScript = nix-update-script {
        attrPath = "dsh-plugin-guard";
        extraArgs = [ "--flake" ];
      };
    };

    meta = {
      description = "Install safety net for DeepSeek Harness: pre-install snapshots, one-click/automatic rollback, guarded boot, and incident reports that auto-trigger agent analysis";
      homepage = "https://github.com/lxzy-7/dsh-plugin-guard";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      mainProgram = "boot-guard.sh";
      platforms = lib.platforms.unix;
    };
  })
