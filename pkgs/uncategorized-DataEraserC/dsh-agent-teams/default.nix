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
  throw "dsh-agent-teams requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-agent-teams)"
else
  dshPkgs.dsh.buildDshBundle.fromPnpmWorkspace (finalAttrs: {
    pname = "dsh-agent-teams";
    version = "0.1.27";

    src = fetchFromGitHub {
      owner = "NanmiCoder";
      repo = "dsh-agent-teams";
      tag = "v${finalAttrs.version}";
      hash = "sha256-S926p62gcEYIPm8KLoemIYuzjIvTLitHV8kjNLMuxtk=";
    };

    deployPackage = "@nanmicoder/dsh-agent-teams";

    pnpmDeps = dshPkgs.dsh.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 4;
      hash = "sha256-PfwfKxR5ApL+iDWESgx8QTYkkX3v/7PMSC0fOAYD6Sw=";
    };

    npmDeps = null;
    npmConfigHook = dshPkgs.pnpmConfigHook;
    npmBuildScript = "build";

    nativeBuildInputs = [ git ];

    doCheck = true;

    checkPhase = ''
      runHook preCheck
      chmod -R u+w scripts
      patchShebangs scripts/doctor.mjs
      node --test scripts/*.test.mjs
      runHook postCheck
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      runHook preInstallCheck
      installedVersion=$(node -p "require('$out/lib/node_modules/@nanmicoder/dsh-agent-teams/package.json').version")
      test "$installedVersion" = "${finalAttrs.version}"
      runHook postInstallCheck
    '';

    postInstall = ''
      test -f $out/lib/node_modules/@nanmicoder/dsh-agent-teams/lib/index.js
      test -f $out/lib/node_modules/@nanmicoder/dsh-agent-teams/lib/client.js
      test -f $out/lib/node_modules/@nanmicoder/dsh-agent-teams/cordis.patch.yml
      test -d $out/lib/node_modules/@nanmicoder/dsh-agent-teams/assets/agent-teams
      if [ -f $out/lib/node_modules/.modules.yaml ]; then sed -i -E -e 's#"prunedAt": "[^"]*"#"prunedAt": "Thu, 01 Jan 1970 00:00:00 GMT"#' -e 's#"storeDir": "[^"]*"#"storeDir": "/build/pnpm-store/v11"#' $out/lib/node_modules/.modules.yaml; fi
      if [ -f $out/lib/node_modules/.pnpm-workspace-state-v1.json ]; then sed -i -E 's#"lastValidatedTimestamp": [0-9]+#"lastValidatedTimestamp": 0#' $out/lib/node_modules/.pnpm-workspace-state-v1.json; fi
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      requiresWeb = true;
      updateScript = nix-update-script {
        attrPath = "dsh-agent-teams";
        extraArgs = [
          "--flake"
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
      changelog = "https://github.com/NanmiCoder/dsh-agent-teams/releases";
      description = "Multi-agent team collaboration for DeepSeek Harness";
      homepage = "https://github.com/NanmiCoder/dsh-agent-teams";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
