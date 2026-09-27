{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  nix-update-script,
  git,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-turn-rewind requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-turn-rewind)"
else
  dshPkgs.dsh.buildDshBundle.fromPnpmWorkspace (finalAttrs: {
    pname = "dsh-turn-rewind";
    version = "0.3.8-unstable-2026-09-26";

    src = fetchFromGitHub {
      owner = "Anionex";
      repo = "dsh-turn-rewind";
      rev = "87f59ef8a0e6c20170926e8cc3bbd13a58528f93";
      hash = "sha256-Jz9GQ0bRthldkbd+ICqZY9blWXTH5uMOk7usQ8oKl4g=";
    };

    deployPackage = "@anionex/dsh-turn-rewind";

    pnpmDeps = dshPkgs.dsh.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 4;
      hash = "sha256-Ex99ufX83CIlxKD6UitEogoGt3U9SCrHBuguWyHtlUw=";
    };

    npmDeps = null;
    npmConfigHook = dshPkgs.pnpmConfigHook;
    npmBuildScript = "build";

    nativeBuildInputs = [ git ];

    doCheck = true;
    checkPhase = ''
      runHook preCheck

      export DSH_TURN_REWIND_HOST_ID=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
      node --test tests/*.test.mjs

      runHook postCheck
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;
    runtimeDeps = [ git ];

    passthru = {
      requiresWeb = true;
      updateScript = nix-update-script {
        attrPath = "dsh-turn-rewind";
        extraArgs = [
          "--flake"
          "--version"
          "branch"
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
      description = "Turn-level conversation and workspace rewind for DeepSeek Harness powered by a persistent Change Ledger";
      homepage = "https://github.com/Anionex/dsh-turn-rewind";
      license = lib.licenses.bsd3;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
