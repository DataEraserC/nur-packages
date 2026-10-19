{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  nix-update-script,
  jq,
  procps,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-free-search requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-free-search)"
else
  dshPkgs.dsh.buildDshBundle.fromPnpmWorkspace (finalAttrs: {
    pname = "dsh-free-search";
    version = "0.9.7";

    src = fetchFromGitHub {
      owner = "DDDMUC";
      repo = "dsh-free-search";
      tag = "v${finalAttrs.version}";
      hash = "sha256-tgJirRujEfQU40/9q184P9KnQhvLcjTnHCqLC7yx6Uk=";
    };

    deployPackage = "dsh-free-search";

    nativeBuildInputs = [ jq ];

    postPatch = ''
      jq '.dsh.bundle.patch = "./cordis.patch.yml"' package.json > package.json.tmp
      mv package.json.tmp package.json
    '';

    pnpmDeps = dshPkgs.dsh.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 4;
      hash = "sha256-8Fw5rawCXOpHPypdoiQoJWGPNTCw32ukEHnP6TJwv5I=";
    };

    npmDeps = null;
    npmConfigHook = dshPkgs.pnpmConfigHook;
    dontNpmBuild = true;

    doCheck = true;

    nativeCheckInputs = [ procps ];

    checkPhase = ''
      runHook preCheck
      for t in tools/assert-*.mjs; do
        node "$t"
      done
      runHook postCheck
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      runHook preInstallCheck
      installedVersion=$(node -p "require('$out/lib/node_modules/dsh-free-search/package.json').version")
      test "$installedVersion" = "${finalAttrs.version}"
      runHook postInstallCheck
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-free-search/lib/index.js
      test -f $out/lib/node_modules/dsh-free-search/lib/client.js
      test -f $out/lib/node_modules/dsh-free-search/cordis.patch.yml
      if [ -f $out/lib/node_modules/.modules.yaml ]; then sed -i -E -e 's#"prunedAt": "[^"]*"#"prunedAt": "Thu, 01 Jan 1970 00:00:00 GMT"#' -e 's#"storeDir": "[^"]*"#"storeDir": "/build/pnpm-store/v11"#' $out/lib/node_modules/.modules.yaml; fi
      if [ -f $out/lib/node_modules/.pnpm-workspace-state-v1.json ]; then sed -i -E 's#"lastValidatedTimestamp": [0-9]+#"lastValidatedTimestamp": 0#' $out/lib/node_modules/.pnpm-workspace-state-v1.json; fi
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      requiresWeb = true;
      updateScript = nix-update-script {
        attrPath = "dsh-free-search";
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
      changelog = "https://github.com/DDDMUC/dsh-free-search/releases";
      description = "Provide free web search with smart engine routing, keyless fallback and a settings UI for DeepSeek Harness";
      homepage = "https://github.com/DDDMUC/dsh-free-search";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
