{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  nix-update-script,
}:

let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
  unwrapped = pkgs.callPackage ../qq-bridge-unwrapped { };
  inherit (unwrapped) version;
in
if inputs == null then
  throw "qq-mode-console requires the deepseek-harness flake input; evaluate it through the flake (nix build .#qq-mode-console)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "qq-mode-console";
    inherit version;

    src = fetchFromGitHub {
      owner = "Derpyu520";
      repo = "qq-bridge";
      rev = "v${version}";
      hash = "sha256-SvepYcZ4hwv5bGHR28vZfKdjRsWGv+eoyTqhxsOx+F0=";
    };

    sourceRoot = "source/plugins/qq-mode-console";

    postPatch = ''
      cp ${finalAttrs.src}/package-lock.json .
    '';

    npmDepsHash = "sha256-T01BWiii+F2nFVqrZTlUVC4C24ajucUTcPMeTS4l2+c=";
    npmFlags = [ "--legacy-peer-deps" ];
    dontNpmBuild = true;

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      inherit unwrapped;
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.5-free";
          involvement = "assisted";
        }
      ];
      updateScript = nix-update-script {
        attrPath = "qq-mode-console";
        extraArgs = [ "--flake" ];
      };
    };

    meta = {
      description = "DSH plugin: QQ bridge mode console for settings UI";
      homepage = "https://github.com/Derpyu520/qq-bridge";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
