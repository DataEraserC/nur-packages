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
    version = "0.3.5";

    src = fetchFromGitHub {
      owner = "FishBottle7";
      repo = "opencode2dsh";
      tag = "v${finalAttrs.version}";
      hash = "sha256-d7b4A/W8BOq6mHS5lp2DNiwgiRv8MZc57R8fjOLjrQg=";
    };

    sourceRoot = "source/packages/plugin";
    deployPackage = "@opencode2dsh/dsh-plugin";

    pnpmDeps = dshPkgs.dsh.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      sourceRoot = "source/packages/plugin";
      fetcherVersion = 4;
      hash = "sha256-oTImIPNGDoTxZnUdgGqRe0hU/cJz2rjnMbaM3Jv/iuw=";
    };

    npmDeps = null;
    npmConfigHook = dshPkgs.pnpmConfigHook;
    npmBuildScript = "prepack";

    passthru.updateScript = nix-update-script {
      attrPath = "opencode2dsh";
      extraArgs = [ "--flake" ];
    };

    passthru.aiProvenance = [
      {
        agent = "dsh";
        involvement = "assisted";
      }
    ];

    meta = {
      changelog = "https://github.com/FishBottle7/opencode2dsh/blob/master/CHANGELOG.md";
      description = "DSH plugin for free OpenCode Zen models with native adapter and no API key";
      homepage = "https://github.com/FishBottle7/opencode2dsh";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
