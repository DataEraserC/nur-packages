# qq-bridge-dsh

## 数据目录必须与 qq-bridge 实际值一致（`$QQ_BRIDGE_HOME`）

本包把 MCP server 从只读 store 启动，经 `cordis.patch.yml` 模板的 `@QQ_BRIDGE_HOME@`（构建期由 `qqBridgeHome` 参数替换）向每个 server 注入 `QQ_BRIDGE_HOME`——**该值必须与 `qq-bridge` 可执行实际使用的数据目录完全一致**（同一 `config.json`、同一 `state/`）。

两边分叉时控制台授权只写进其中一侧，MCP 会把控制台访问令牌暴露进工具参数流，agent 会反过来要求聊天用户重新配置——实测事故症状原文：

> 该控制台访问令牌无法作为 QQ 工具参数直接传入。请把它配置到 SnowLuma/QQ 桥接的控制台授权设置中，配置完成后回复“已配置”，我再继续读取并回复群消息。

当前接线（两侧解析到同一目录，可用）：

- `qq-bridge` 侧默认动态展开 `${XDG_DATA_HOME:-$HOME/.local/share}/qq-bridge`，见 [`../qq-bridge/AGENTS.md`](../qq-bridge/AGENTS.md)；
- 本包参数的**默认值是字面量** `~/.local/share/qq-bridge`：整条链路没有 `~` 展开层——`dsh-mcp-client` 的 `buildChildEnv` 原样透传 env、spawn 不经 shell、补丁后的 `ROOT = process.env.QQ_BRIDGE_HOME || …` 直接使用字符串（实盘亦无任何字面 `~` 目录）。因此该默认**不可用**，必须显式 override 成绝对路径：下游 nix-config 的 `qqBundles` 正是这么传的，这也是系统一直正常的原因；
- 两侧对齐完全依赖 override 纪律：`qq-bridge` 包有同名 `qqBridgeHome` override 参数，联用时两侧必须 override 成同一个值，可用 `passthru.qqBridgeHome` 自检。

改动任意一侧的数据目录解析方式时，必须同步另一侧。
