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
  throw "dsh-annotation requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-annotation)"
else
  dshPkgs.dsh.buildDshBundle.fromPnpmWorkspace (finalAttrs: {
    pname = "dsh-annotation";
    version = "1.4.11-preview.1";

    src = fetchFromGitHub {
      owner = "omdsh-dev";
      repo = "dsh-annotation";
      tag = "v${finalAttrs.version}";
      hash = "sha256-+lO054XGjpBRdDUIFIhoWdh5sANsLOD2J+Fi2gYZyjU=";
    };

    deployPackage = "@changfenhuang/dsh-annotation";

    pnpmDeps = dshPkgs.dsh.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 4;
      hash = "sha256-UWsREIbFvYl5zB2YRVFmA3KKguVK2Lp1U/07zQ9wUvs=";
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
      installedVersion=$(node -p "require('$out/lib/node_modules/@changfenhuang/dsh-annotation/package.json').version")
      test "$installedVersion" = "${finalAttrs.version}"
      runHook postInstallCheck
    '';

    postInstall = ''
      test -f $out/lib/node_modules/@changfenhuang/dsh-annotation/lib/index.js
      test -f $out/lib/node_modules/@changfenhuang/dsh-annotation/client.js
      test -f $out/lib/node_modules/@changfenhuang/dsh-annotation/cordis.patch.yml
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      requiresWeb = true;
      updateScript = nix-update-script {
        attrPath = "dsh-annotation";
        extraArgs = [
          "--flake"
          "--version"
          "unstable"
        ];
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
      changelog = "https://github.com/omdsh-dev/dsh-annotation/releases";
      description = "Annotate selected assistant text in the DeepSeek Harness web UI and reply to each annotation by number";
      homepage = "https://github.com/omdsh-dev/dsh-annotation";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
