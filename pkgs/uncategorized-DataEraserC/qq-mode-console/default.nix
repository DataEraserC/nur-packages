{
  lib,
  pkgs,
  inputs ? null,
}:

let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
  unwrapped = pkgs.callPackage ../qq-bridge-unwrapped { };
  inherit (unwrapped) version;
in
if inputs == null then
  throw "qq-mode-console requires the deepseek-harness flake input; evaluate it through the flake (nix build .#qq-mode-console)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "qq-mode-console";
    inherit version;

    # src/npmDepsHash 跟随 qq-bridge-unwrapped（同仓库同 tag、同一把根 lock、同一组 npmFlags）。
    # 历史教训：本包曾自带 fetchFromGitHub+本地 hash，而 version 继承 unwrapped 会自动涨号，
    # auto-update 又因文件里没有 version 行从不更新它 → v0.1.7 切换后实际部署 0.1.5 内容
    # （cachix 替换掩盖、冷构建 hash mismatch）。改为全派生后此类脱钩在结构上不可能发生。
    inherit (unwrapped) src;

    sourceRoot = "source/plugins/qq-mode-console";

    postPatch = ''
      cp ${finalAttrs.src}/package-lock.json .
    '';

    inherit (unwrapped) npmDepsHash;
    npmFlags = [ "--legacy-peer-deps" ];
    dontNpmBuild = true;

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      inherit unwrapped;
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.5-free";
          involvement = "assisted";
        }
      ];
      # 无需 updateScript：src/version/npmDepsHash 全部继承自 qq-bridge-unwrapped，
      # bot 更新 unwrapped 时本包自动跟随，本地没有任何需要单独 bump 的 pin。
    };

    meta = {
      description = "DSH plugin: QQ bridge mode console for settings UI";
      homepage = "https://github.com/Derpyu520/qq-bridge";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
