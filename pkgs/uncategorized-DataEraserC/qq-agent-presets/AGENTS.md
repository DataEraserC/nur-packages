# qq-agent-presets

qq-bridge 两个 DSH agent 预设（qq-chat / qq-chat-v2）与执行期工具守卫
（qq-tool-restrict）的**独立 bundle**。与上游 `setup-dsh.mjs` 注册的形态
逐字一致：patch 就是上游入库的 `plugins/qq-agent-presets/presets/*.patch.yml`
（构建期不生成、不改写，`dsh.bundle.patch` 数组原样生效）。

## 与 qq-bridge-dsh 的分工

- **本包**：preset 行（`@deepseek-ai/dsh-agent-preset` + 内联插件列表）与守卫实现；
- **qq-bridge-dsh**：bridge 树与三个 MCP server 行（`@QQ_BRIDGE_HOME@`/`@NODE@`/
  `@PKGDIR@` 替换见其 AGENTS.md）。

历史注记：preset 行曾由 `qq-bridge-dsh` 内的 `generate-preset-rows.py` 生成
并指向 `$out/share` 拷贝（0.1.5 workaround，0.1.7 起上游改 re-export 壳后断链）。
现走上游原生路径——本包注册进安装锚点后，守卫行的裸说明符
`qq-agent-presets/qq-tool-restrict.mjs` 由 dsh 运行时解析（dsh-app-boot 的
runtime resolution 会把选中 bundle 的包供给 Node ESM/CJS 解析器），整条
生成/重写链已退役。

## 数据目录（本包无关）

守卫只做工具名白名单，不读 `config.json`/`state/`；数据目录纪律见
[`../qq-bridge-dsh/AGENTS.md`](../qq-bridge-dsh/AGENTS.md)。

## 工具白名单 extra（`extraAllowedTools` override，自 qq-bridge-dsh 迁入）

`qq-tool-restrict.mjs` 在执行期用白名单把关：`SAFE_PREFIXES`（MCP 命名空间
前缀，`__` 结尾条目）与 `SAFE_EXACT`（精确名）之外一律拒绝；
`KNOWN_DANGEROUS_GLOBAL_TOOLS`（dev\_\_ 管理工具）永远拒绝。host 层
`mcp-snowluma-safe` 的 `allow.groups` / `allow.private` 是「目标群/私聊」
维度的门，与工具名白名单无关。

追加工具名单走包 override（改列表 = 重建生效）：

```nix
nur-DataEraserC.packages.${pkgs.system}.qq-agent-presets.override {
  extraAllowedTools = [
    "mcp__my-server__"   # 以 __ 结尾 → 追加为命名空间前缀（SAFE_PREFIXES）
    "some_exact_tool"    # 其余      → 追加为精确名（SAFE_EXACT）
  ];
}
```

- 构建期注入：`extraAllowedTools != []` 时向包内权威实现
  `lib/node_modules/qq-agent-presets/qq-tool-restrict.mjs` 末尾追加注入块；
  默认 `[]` 时不改任何文件（与不带 override 的产物逐字节一致）。
- 安全边界不降级：名单里混入 `KNOWN_DANGEROUS_GLOBAL_TOOLS` 的名字会在
  注入块里被跳过——schema 层 restrict + 执行层 guard 的双拒不受影响。
- 生效值可用 `passthru.extraAllowedTools` 自检。
- 下游 nix-config 在 `qqBundles` 的 `.override` 处传入。

## src/npmDepsHash 纪律（与 qq-mode-console 相同）

全部继承 `qq-bridge-unwrapped`（同仓库同 tag、同一把根 lock、同一组
npmFlags）。**不要**在本包本地钉 `src` hash 或 `npmDepsHash`：version 也
继承 unwrapped，本地 pin 会在 bot 更新时脱钩（历史教训见
qq-mode-console 0.1.5 内容贴 0.1.7 标事故）。
