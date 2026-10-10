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
  throw "dsh-share requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-share)"
else
  dshPkgs.dsh.buildDshBundle.fromPnpmWorkspace (finalAttrs: {
    pname = "dsh-share";
    version = "0.5.0";

    src = fetchFromGitHub {
      owner = "hellodigua";
      repo = "dsh-share";
      tag = "v${finalAttrs.version}";
      hash = "sha256-0hQIXneC7TYw7JipaPmrCroyn1cnn+/aCDijJ0ub2OY=";
    };

    deployPackage = "dsh-share";

    pnpmDeps = dshPkgs.dsh.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 4;
      hash = "sha256-ExGuzb6jtuS5fNWiWoUXVRHhYGPnLmwtfPBuNaV+h9Q=";
    };

    npmDeps = null;
    npmConfigHook = dshPkgs.pnpmConfigHook;
    npmBuildScript = "build";

    doCheck = true;

    checkPhase = ''
      runHook preCheck
      npm test
      runHook postCheck
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      runHook preInstallCheck
      installedVersion=$(node -p "require('$out/lib/node_modules/dsh-share/package.json').version")
      test "$installedVersion" = "${finalAttrs.version}"
      runHook postInstallCheck
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-share/lib/index.js
      test -f $out/lib/node_modules/dsh-share/lib/client.js
      test -f $out/lib/node_modules/dsh-share/cordis.patch.yml
      test -f $out/lib/node_modules/dsh-share/locale/zh.json
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      requiresWeb = true;
      updateScript = nix-update-script {
        attrPath = "dsh-share";
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
      changelog = "https://github.com/hellodigua/dsh-share/releases";
      description = "Share selected DeepSeek Harness conversations as PNG images or Markdown text";
      homepage = "https://github.com/hellodigua/dsh-share";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
