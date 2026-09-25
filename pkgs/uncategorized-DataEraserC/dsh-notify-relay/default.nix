{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-notify-relay requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-notify-relay)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-notify-relay";
    version = "0.4.3";

    src = fetchFromGitHub {
      owner = "Archaofan";
      repo = "dsh-notify-relay";
      tag = "v${finalAttrs.version}";
      hash = "sha256-SsGc+ARR1ZJYYVegckngW+fMeGsM0a4/EtomW66gGSc=";
    };

    npmDepsHash = "sha256-qXTR4b5Z3tJjtmfKOC7ikrndb0WVU5XW3WDPogHT+NI=";

    dontNpmBuild = true;

    postPatch = ''
      sed -i 's|"version": "[^"]*"|"version": "${finalAttrs.version}"|' package.json
      cp ${./package-lock.json} package-lock.json
      chmod u+w package-lock.json
    '';

    doCheck = true;

    checkPhase = ''
      runHook preCheck
      node .sandbox/gate.cjs
      runHook postCheck
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-notify-relay/index.js
      test -f $out/lib/node_modules/dsh-notify-relay/client.js
      test -f $out/lib/node_modules/dsh-notify-relay/cordis.patch.yml
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.6-flash-free";
          involvement = "authored";
        }
      ];
      updateScript = [ (toString ./update.sh) ];
    };

    meta = {
      changelog = "https://github.com/Archaofan/dsh-notify-relay/releases";
      description = "Outbound notification rule center for DeepSeek Harness that deduplicates, mutes and batches lifecycle events before pushing them to Bark, Telegram, ntfy, Feishu, WeCom, DingTalk, ServerChan or any webhook";
      homepage = "https://github.com/Archaofan/dsh-notify-relay";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
