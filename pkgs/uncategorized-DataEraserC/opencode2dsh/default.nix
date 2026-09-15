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
  throw "opencode2dsh requires the deepseek-harness flake input; evaluate it through the flake (nix build .#opencode2dsh)"
else
  dshPkgs.dsh.buildDshBundle.fromPnpmWorkspace (finalAttrs: {
    pname = "opencode2dsh";
    version = "0.3.1";

    src = fetchFromGitHub {
      owner = "FishBottle7";
      repo = "opencode2dsh";
      tag = "v${finalAttrs.version}";
      hash = "sha256-IdSV3pSC2XT4nGM8bZo9ffQQxADhtf4VjcLbzI/POOs=";
    };

    sourceRoot = "source/packages/plugin";
    deployPackage = "@opencode2dsh/dsh-plugin";

    pnpmDeps = dshPkgs.dsh.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      sourceRoot = "source/packages/plugin";
      fetcherVersion = 4;
      hash = "sha256-Z+l+sOI3AKW0jS6KkuzlnZzLHBAWt9/+VaIONEi1Vag=";
    };

    npmDeps = null;
    npmConfigHook = dshPkgs.pnpmConfigHook;
    npmBuildScript = "prepack";

    passthru.updateScript = nix-update-script {
      attrPath = "opencode2dsh";
      extraArgs = [ "--flake" ];
    };

    meta = {
      changelog = "https://github.com/FishBottle7/opencode2dsh/blob/master/CHANGELOG.md";
      description = "DSH plugin for free OpenCode Zen models with native adapter and no API key";
      homepage = "https://github.com/FishBottle7/opencode2dsh";
      license = lib.licenses.mit;
      maintainers = [
        {
          name = "DataEraserC";
          github = "DataEraserC";
        }
      ];
      platforms = lib.platforms.unix;
    };
  })
