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
  throw "dsh-chat-import requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-chat-import)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-chat-import";
    version = "0.26.9";

    src = fetchFromGitHub {
      owner = "Nwflower";
      repo = "dsh-chat-import";
      tag = "v${finalAttrs.version}";
      hash = "sha256-MkmmcavpDdHrhIL3wPYKt1T9mRsECGlDHK0grK5T+u4=";
    };

    npmDepsHash = "sha256-sjpfcOZsAHKKi/b5Ilc9L3TUrDYVaW4u4phor7uThJw=";

    doCheck = true;

    checkPhase = ''
      runHook preCheck
      npm test
      runHook postCheck
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      runHook preInstallCheck
      installedVersion=$(node -p "require('$out/lib/node_modules/dsh-chat-import/package.json').version")
      test "$installedVersion" = "${finalAttrs.version}"
      runHook postInstallCheck
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-chat-import/lib/client.js
      test -f $out/lib/node_modules/dsh-chat-import/cordis.patch.yml
      test -x $out/bin/dsh-chat-import
    '';

    installation = dshPkgs.dsh.dsh-runtime;

    passthru = {
      requiresWeb = true;
      updateScript = nix-update-script {
        attrPath = "dsh-chat-import";
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
      changelog = "https://github.com/Nwflower/dsh-chat-import/releases";
      description = "Import conversation history from 25+ AI coding agents into DeepSeek Harness as resumable sessions with tool calls and reasoning intact";
      homepage = "https://github.com/Nwflower/dsh-chat-import";
      license = lib.licenses.mit;
      mainProgram = "dsh-chat-import";
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
