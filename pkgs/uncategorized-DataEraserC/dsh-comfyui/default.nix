{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  nix-update-script,
  xdg-utils,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-comfyui requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-comfyui)"
else
  dshPkgs.dsh.buildDshBundle.fromPnpmWorkspace (finalAttrs: {
    pname = "dsh-comfyui";
    version = "0.5.5";

    src = fetchFromGitHub {
      owner = "fandc520";
      repo = "dsh-comfyui";
      tag = "v${finalAttrs.version}";
      hash = "sha256-dhFQjQP9b4wtNT4n1pFVO4khHc1NRjcdiP88yYxMy7o=";
    };

    deployPackage = "dsh-comfyui";

    pnpmDeps = dshPkgs.dsh.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 4;
      hash = "sha256-A5BSa/udoi+31W218xsT48V2TPzA0jp7VYjCkpm9+Jw=";
    };

    npmDeps = null;
    npmConfigHook = dshPkgs.pnpmConfigHook;
    npmBuildScript = "build";

    doCheck = true;

    checkPhase = ''
      runHook preCheck
      npm run typecheck
      for t in test-host-compat test-store-params test-skillpack test-transfer test-convert; do
        node "scripts/$t.mjs"
      done
      runHook postCheck
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      runHook preInstallCheck
      installedVersion=$(node -p "require('$out/lib/node_modules/dsh-comfyui/package.json').version")
      test "$installedVersion" = "${finalAttrs.version}"
      runHook postInstallCheck
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-comfyui/lib/index.js
      test -f $out/lib/node_modules/dsh-comfyui/client/client.js
      test -f $out/lib/node_modules/dsh-comfyui/cordis.patch.yml
      if [ -f $out/lib/node_modules/.modules.yaml ]; then sed -i -E -e 's#"prunedAt": "[^"]*"#"prunedAt": "Thu, 01 Jan 1970 00:00:00 GMT"#' -e 's#"storeDir": "[^"]*"#"storeDir": "/build/pnpm-store/v11"#' $out/lib/node_modules/.modules.yaml; fi
      if [ -f $out/lib/node_modules/.pnpm-workspace-state-v1.json ]; then sed -i -E 's#"lastValidatedTimestamp": [0-9]+#"lastValidatedTimestamp": 0#' $out/lib/node_modules/.pnpm-workspace-state-v1.json; fi
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    runtimeDeps = [ xdg-utils ];

    passthru = {
      requiresWeb = true;
      updateScript = nix-update-script {
        attrPath = "dsh-comfyui";
        extraArgs = [ "--flake" ];
      };
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.6-flash-free";
          involvement = "authored";
        }
      ];
    };

    meta = {
      changelog = "https://github.com/fandc520/dsh-comfyui/releases";
      description = "Drive a local or remote ComfyUI from DeepSeek Harness with workflow, asset and queue panels plus per-workflow skill packs";
      homepage = "https://github.com/fandc520/dsh-comfyui";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
