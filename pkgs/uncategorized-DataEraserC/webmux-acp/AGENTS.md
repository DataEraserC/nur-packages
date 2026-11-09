# webmux-acp

`webmux` + 一个**只新增文件**的补丁：让没有内置 adapter 的 ACP CLI 通过一张声明表
加入混合会话，不改 Go 代码、不改启动配置格式。

## 为什么是「只新增文件」

上游的 agent 表是源码常量：

```go
// internal/agentprofile/agents/agents.go
var defaultRegistry = agentprofile.NewRegistry(omp.Agent, opencode.Agent, codex.Agent, ...)
```

`NewRegistry` 只要求 name 唯一，注册表本身是不可变值。所以补丁不碰这一行，而是在**同一个包里**
新增文件，用 `init()` 重设这个包级变量：

```go
func init() {
    builtins := defaultRegistry.Agents()
    defaultRegistry = agentprofile.NewRegistry(append(builtins, external()...)...)
}
```

新增的两个文件：

| 文件 | 内容 |
|---|---|
| `internal/agentprofile/spec.go` | `Spec` 类型、校验、`Spec.Agent()`（`Identify` 恒 false，交给 `session/list` 兜底） |
| `internal/agentprofile/agents/external.go` | `init()` 扩展注册表 + 读 `WEBMUX_ACP_AGENTS` |

**上游文件一处未改**，`diff -r` 只多这两个文件。这带来两个直接好处：

1. `nix-update` 升版本不会冲突，补丁继续可用；
2. 万一上游真的改坏了这个机制（重命名 `defaultRegistry`、或新增同名文件），是**编译期报错**，
   而不是运行期静默失效。

## 声明表

环境变量 `WEBMUX_ACP_AGENTS`，JSON：可执行文件基名 → 描述。

```json
{
  "codebuddy": {
    "title": "CodeBuddy",
    "acpArg": "--acp",
    "resumeFlag": "--resume"
  }
}
```

| 字段 | 含义 | 缺省 |
|---|---|---|
| `kind` | 协议族，目前只有 `acp` | `acp` |
| `title` | 显示名 | 可执行文件基名 |
| `icon` | 启动配置图标目录里的 key | `terminal` |
| `acpArg` | 拉起 ACP 的旗标或子命令（`--acp` / `acp`） | 子命令 `acp` |
| `resumeFlag` | 终端侧续开会话的旗标，后接 session id | 空，退化为 `session/load` |
| `identity` | 终端进程与会话的匹配方式，目前只有 `none` | `none`（靠 `session/list`） |

坏条目只打一条 warn 并跳过（打字错误不会让整个服务起不来），与内置 profile 重名也跳过。

**启动配置不用带任何新字段**：`cmd: ["codebuddy"]` + 勾上混合模式即可，因为 agent 是按
命令名注册的，跟上游识别内置 agent 的方式一致。

## 能力边界

- `identity` 只有 `none`：锁文件（claude）、进程注册表（opencode）这类身份来源仍是代码。
  对不提供 `session/list` 的 CLI，还要配一个像 `codebuddy-acp` 那样的代理包来补。
- 名字一旦声明就写进会话记录（`hybrid-sessions.json` 的 `agent` 字段），改名会影响恢复。
- 声明表是进程级的：加 agent 要重启服务，不能在网页里临时加。

## NixOS 侧

```nix
systemd.services.webmux.environment.WEBMUX_ACP_AGENTS = builtins.toJSON {
  codebuddy = { title = "CodeBuddy"; acpArg = "--acp"; resumeFlag = "--resume"; };
};
```

## 验收

```
nix build .#webmux-acp
WEBMUX_ACP_AGENTS='{"codebuddy":{"acpArg":"--acp","resumeFlag":"--resume"}}' \
  webmux serve ...
GET /api/launch-configs → hybridSupport.supported: true, agent: "codebuddy"
建会话（tui）→ switch → force → side: acp + agentSessionId 自动识别 → 聊天有回复
```

`WEBMUX_ACP_AGENTS` 为空时，行为与上游逐字一致（注册表就是内置那 7 个）。

## 上游

先本地用。这套东西对上上游是一份「声明式扩展点」的提案：`Spec` 加一个 `init()`，
不改变任何既有判据，也不引入配置迁移。用稳了再提。
