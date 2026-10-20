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
    version = "0.3.14";

    src = fetchFromGitHub {
      owner = "FishBottle7";
      repo = "opencode2dsh";
      tag = "v${finalAttrs.version}";
      hash = "sha256-pH69IIVEAOiulc6es0UXExdN+0vRbStUnMEEZ4Bp4bA=";
    };

    sourceRoot = "source/packages/plugin";
    deployPackage = "@opencode2dsh/dsh-plugin";

    postPatch = ''
      substituteInPlace tsdown.client.config.ts --replace-fail 'for (const [local, exp] of Object.entries(cssExports ?? {})) classMap[local] = exp.name' 'for (const [local, exp] of Object.entries(cssExports ?? {}).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))) classMap[local] = exp.name'
    '';

    pnpmDeps = dshPkgs.dsh.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      sourceRoot = "source/packages/plugin";
      fetcherVersion = 4;
      hash = "sha256-DzhOM+nK03CB5d59SFnoW1yWaiP7+tMYe+Nl5ImwXEs=";
    };

    npmDeps = null;
    npmConfigHook = dshPkgs.pnpmConfigHook;
    npmBuildScript = "prepack";

    postInstall = ''
      if [ -f $out/lib/node_modules/.modules.yaml ]; then sed -i -E -e 's#"prunedAt": "[^"]*"#"prunedAt": "Thu, 01 Jan 1970 00:00:00 GMT"#' -e 's#"storeDir": "[^"]*"#"storeDir": "/build/pnpm-store/v11"#' $out/lib/node_modules/.modules.yaml; fi
      if [ -f $out/lib/node_modules/.pnpm-workspace-state-v1.json ]; then sed -i -E 's#"lastValidatedTimestamp": [0-9]+#"lastValidatedTimestamp": 0#' $out/lib/node_modules/.pnpm-workspace-state-v1.json; fi
    '';

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
