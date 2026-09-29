{
  lib,
  pkgs,
  inputs ? null,
  # Extra entries admitted by the presets' execution-time tool guard
  # (qq-tool-restrict.mjs). Entries ending in "__" extend the MCP namespace
  # prefix whitelist (SAFE_PREFIXES); all others extend the exact-name set
  # (SAFE_EXACT). Known-dangerous global tools stay denied regardless.
  # Override via: pkgs.qq-agent-presets.override { extraAllowedTools = [ ... ]; }
  extraAllowedTools ? [ ],
  # TEMP-TEST(qq_get_message_media): 允许注入本地 fork 构建的 unwrapped
  # （presets 的 src 跟随 unwrapped.src，fork 里改了 preset 也要跟上）。
  unwrapped ? pkgs.callPackage ../qq-bridge-unwrapped { },
}:

let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
  inherit (unwrapped) version;

  # Appended to qq-tool-restrict.mjs at build time (moved here from
  # qq-bridge-dsh when presets became their own bundle). The block runs at
  # module load after the whitelist consts: "__"-suffixed entries join
  # SAFE_PREFIXES, others join SAFE_EXACT, and names in
  # KNOWN_DANGEROUS_GLOBAL_TOOLS are skipped so the deny layer stays absolute.
  extraToolsSnippet = lib.optionalString (extraAllowedTools != [ ]) ''
    # ── nix override: extraAllowedTools（构建期注入，勿手工编辑） ──
    implFile="$out/lib/node_modules/qq-agent-presets/qq-tool-restrict.mjs"
    chmod u+w "$implFile"
    cat >> "$implFile" <<'QQ_TOOL_EXTRA'

    // ── nix override: extraAllowedTools（构建期注入，勿手工编辑） ──
    for (const t of ${builtins.toJSON extraAllowedTools}) {
      if (typeof t !== 'string' || t.length === 0) continue
      if (KNOWN_DANGEROUS_GLOBAL_TOOLS.includes(t)) continue
      if (t.endsWith('__')) {
        if (!SAFE_PREFIXES.includes(t)) SAFE_PREFIXES.push(t)
      } else {
        SAFE_EXACT.add(t)
      }
    }
    QQ_TOOL_EXTRA
  '';
in
if inputs == null then
  throw "qq-agent-presets requires the deepseek-harness flake input; evaluate it through the flake (nix build .#qq-agent-presets)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "qq-agent-presets";
    inherit version;

    # src/npmDepsHash 跟随 qq-bridge-unwrapped（同仓库同 tag、同一把根 lock、
    # 同一组 npmFlags）——与 qq-mode-console 同一条纪律：本地零 pin，
    # bot 更新 unwrapped 时本包自动跟随，杜绝「version 涨号、hash 钉死」脱钩。
    inherit (unwrapped) src;

    sourceRoot = "source/plugins/qq-agent-presets";

    postPatch = ''
      cp ${finalAttrs.src}/package-lock.json .
      # 零依赖包：npm install 不会创建 node_modules，而 npmInstallHook 结尾的
      # find node_modules 在目录缺失时非零退出（buildDshBundle 走 npm 流水线的
      # 必需前置）。npm 只修剪包条目、不删除预建的空目录。
      mkdir -p node_modules
    '';

    inherit (unwrapped) npmDepsHash;
    npmFlags = [ "--legacy-peer-deps" ];
    dontNpmBuild = true;

    # 上游 presets/*.patch.yml 直接入包（dsh.bundle.patch 数组，构建期由
    # validateDshBundle 校验每个文件存在）；守卫行用裸说明符
    # qq-agent-presets/qq-tool-restrict.mjs —— 本包作为注册 bundle 进入安装
    # 锚点后由 dsh 运行时解析（dsh-app-boot 的 runtime resolution），无需
    # profile 侧 node_modules。组件行零拷贝、零改写，与上游逐字一致。
    postInstall = ''
      ${extraToolsSnippet}
    '';

    passthru = {
      inherit unwrapped extraAllowedTools;
      # buildDshBundle 注入 dshBundle/dshBundleHelper/runtimeDeps 协议字段
      # （validateDshBundle 校验）；registry（nix-support/dsh-bundles.json）
      # 由 validateInstalledBundle 按 package.json 的 dsh.bundle.patch 自动
      # 生成，patch 数组原样写入。
    };

    meta = {
      description = "DSH bundle for qq-bridge: agent presets (qq-chat, qq-chat-v2) and the qq-tool-restrict guard";
      homepage = "https://github.com/Derpyu520/qq-bridge";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
