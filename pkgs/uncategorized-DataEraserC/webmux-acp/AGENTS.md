# webmux-acp

测试用的 `webmux` 覆盖包：在**主包 `webmux` 当前版本**之上叠加一份本地补丁，
提供通用的外部 ACP agent / 包装命令接入。主包自身保持干净、继续走自动更新；
本包 `updateScript = null`，不参与自动更新，也不会向上游发 PR。

## 基线与补丁来源

- 主包 `../webmux/default.nix` 由 `nix-update-script` 跟进上游 release
  （`mzdluo123/webmux`）。此前卡在 `v0.12.1` 是自动更新 CI 的问题，不是
  需要 backport 的理由；修好 CI 后主包已跟进到新版。
- `patches/external-acp-agents.patch` 来自上游仓库本地分支
  `feat/external-acp-agents`（基于 `origin/main`，未 push、未 PR）相对其基线
  的 `internal/agentprofile/` 差异。上游 release 与 main 之间若未改动该目录，
  补丁可直接叠加；升级主包版本后需重新 `git apply --check` 验证。
- 补丁共 8 个 Go 文件：`spec.go`、`wrapper.go`、`agents/external.go`、
  两个 `*_test.go`，以及对 `command.go` / `profile.go` / `registry.go` 的修改。

## 两张声明表

`WEBMUX_ACP_AGENTS`：可执行文件基名 → `Spec`，声明任意没有内置 adapter 的
ACP CLI。字段：

| 字段 | 含义 | 缺省 |
|---|---|---|
| `kind` | 协议族，目前只有 `acp` | `acp` |
| `title` | 显示名（≤64 字符） | 可执行文件基名 |
| `icon` | 启动配置图标 key | `terminal` |
| `acpArg` | 拉起 ACP 的旗标或子命令（`--acp` / `acp`） | 子命令 `acp` |
| `acpExe` | 协议补齐 shim 的基本名 | 空，用 agent 本体 |
| `resumeFlag` | 终端侧续开会话的旗标，后接 session id | 空，退化为 `session/load` |
| `identity` | 终端信号身份，声明式档案只有 `none` | `none`（靠 `session/list`） |
| `launcher` | 解释器作为 PTY 根进程时的基名 | 空 |

`WEBMUX_AGENT_WRAPPERS`：包装器可执行文件基名 → `{"args": N, "launcher": "..."}`，
声明任意包装命令。`args` 是包装器固定前缀参数个数（1–8），第一个参数必须
命名已注册 agent，其余原样透传；`launcher` 处理 `bwrap` 这类 fork 后保留
根进程、agent 是其子进程的情形。

```json
{
  "codebuddy": {
    "title": "CodeBuddy",
    "acpArg": "--acp",
    "acpExe": "codebuddy-acp",
    "resumeFlag": "--resume"
  }
}
```

```json
{ "multi-instance": { "args": 2, "launcher": "bwrap" } }
```

配上这两张表，`multi-instance codebuddy 1` / `2` / `work` / `home`
都会被识别为 `codebuddy` 的混合会话，且 `TUIArgv` / `ResumeArgv` / `ACPArgv`
重建时保留完整包装前缀。**任何提供 ACP 的 CLI 都用同一套声明**，没有
CodeBuddy 专用选项。

坏条目只打一条 warn 并跳过；与内置档案重名的声明被跳过；两张表都不设置时
行为与上游逐字一致。

## 为什么不在下游生成包装器

曾经的方案是按声明生成同名薄包装器塞进 `environment.systemPackages`，
会让系统可执行文件随实例数量增长，属于污染，已废弃。现在由 WebMux 在
`Registry.Parse` 里识别包装器并记住 `Command.identity`，不需要任何额外的
可执行文件。

## `acpExe` 与包装运行

CodeBuddy 2.180.0 的 stdio ACP 不实现 `session/list`，需要
`codebuddy-acp` 补齐。该 shim 只以独立名字安装，不影子化全局 `codebuddy`。

- **直接运行** `codebuddy`：`acpExe` 生效，`ACPArgv` 变成
  `codebuddy-acp --acp`。
- **包装运行** `multi-instance codebuddy 1`：`ACPArgv` 保持
  `multi-instance codebuddy 1 --acp`，**不注入 shim**。包装器内部用
  `command -v codebuddy` 解析可执行文件，把 shim 当额外参数插进去会被
  `multi-instance` 当成传给 agent 的普通参数。需要 shim 的部署在 WebMux
  **会话 PATH**（服务级专用目录，不进 `environment.systemPackages`）里
  以 `codebuddy` 之名提供它。

## 能力边界

- 声明式档案 `Identify` 恒 false：不做终端信号身份，会话匹配回退
  `session/list` 候选探测（只读、安全）。
- 名字写进 `hybrid-sessions.json` 的 `agent` 字段，改名影响恢复。
- 声明表是进程级的：加 agent 要重启服务。
- `acpExe` 只解决协议缺口；CLI 本身未登录、无 transcript 时，
  `session/load` 仍会失败并按设计回滚到终端视图。

## 验收

```
nix build .#webmux-acp
WEBMUX_ACP_AGENTS='{"codebuddy":{"acpArg":"--acp","resumeFlag":"--resume"}}' \
WEBMUX_AGENT_WRAPPERS='{"multi-instance":{"args":2,"launcher":"bwrap"}}' \
  webmux serve --listen 127.0.0.1:1110
GET /api/launch-configs → 上述四条命令的 hybridSupport.supported: true
建会话（tui）→ view 切换（choice: force）→ ACP initialize / session/list / session/load
```

## 上游

补丁是本地测试产物，**不要 push、不要开 PR**。等测试稳定后再决定是否
向上游提案。
