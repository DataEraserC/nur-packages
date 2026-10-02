{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  google-chrome,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-ego-browser requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-ego-browser)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-ego-browser";
    version = "0.8.6";

    src = fetchFromGitHub {
      owner = "Fisfzy";
      repo = "dsh-ego-browser";
      tag = "v${finalAttrs.version}";
      hash = "sha256-+ofhEKvhTjrelZEgOChk6IR+LTp3smlxG3vaXJmOOL0=";
    };

    npmDepsHash = "sha256-/mX8sAIUGrSevbNAao+i39pe/bsKvWOIY/Y846cxqRk=";

    patches = [ ./tests-cross-platform.patch ];

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
      chmod u+w package-lock.json
    '';

    doCheck = true;

    preCheck = ''
      kernelScope=${dshPkgs.dsh.dsh-kernel}/lib/deepseek-harness/node_modules/@deepseek-ai
      mkdir -p node_modules/@deepseek-ai
      for pkg in "$kernelScope"/*; do
        name=$(basename "$pkg")
        if [ ! -e "node_modules/@deepseek-ai/$name" ]; then
          ln -s "$pkg" "node_modules/@deepseek-ai/$name"
        fi
      done
    '';

    checkPhase = ''
      runHook preCheck
      npm test
      runHook postCheck
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      runHook preInstallCheck
      installedVersion=$(node -p "require('$out/lib/node_modules/dsh-ego-browser/package.json').version")
      test "$installedVersion" = "${finalAttrs.version}"
      runHook postInstallCheck
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-ego-browser/lib/index.js
      test -f $out/lib/node_modules/dsh-ego-browser/lib/client.js
      test -f $out/lib/node_modules/dsh-ego-browser/dsh-plugin.json
      test -f $out/lib/node_modules/dsh-ego-browser/cordis.patch.yml
      test -f $out/lib/node_modules/dsh-ego-browser/bin/ego-chrome-wrapper.sh
      test -f $out/lib/node_modules/dsh-ego-browser/bin/ego-cast-worker.mjs
      test -f $out/lib/node_modules/dsh-ego-browser/runtime/ego-linux/bin/ego-browser.mjs
    '';

    runtimeDeps = [ google-chrome ];
    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.6-flash-free";
          involvement = "authored";
        }
      ];
      requiresWeb = true;
      updateScript = [ (toString ./update.sh) ];
    };

    meta = {
      changelog = "https://github.com/Fisfzy/dsh-ego-browser/releases";
      description = "Chrome-driven browser automation bundle for DeepSeek Harness with 32 ego_* tools, CDP/FFmpeg capture, casting and a live observation panel";
      descriptions.zh-CN = "由 Chrome 驱动的 DeepSeek Harness 浏览器自动化插件，提供 32 个 ego_* 工具、CDP/FFmpeg 录制、投屏与实时观察面板";
      homepage = "https://github.com/Fisfzy/dsh-ego-browser";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
