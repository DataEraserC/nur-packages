# xiaohuanxiong-acp

Raccoon Work 的 ACP 桥 + Martty 终端 UI。安装 `xiaohuanxiong-acp`，另有 `xiaohuanxiong-acp-resume` 符号链接（`argv[0]` 以 `-resume` 结尾时自动补 `--resume`）。

- **状态目录**：`BOX_AGENT_HOME` 优先；`MULTI_INSTANCE` 下用 `$HOME/.box-agent`，否则 `$XDG_STATE_HOME/xiaohuanxiong-acp/box-agent`。`BOX_AGENT_CONFIG_DIR` / `MARTTY_HOME` 默认在其下；`prepareState` 建 0700 目录并 seed 一次 `config.yaml`。桌面 `xiaohuanxiong` 也用 `~/.box-agent`，但 multi-instance 的 `stateDirectoryKey` 不同，互不影响。
- **`session/list` 的 UUID 必须从首行 `type == "session"` 记录取，不能用文件名**：Box-Agent 所有 transcript 都叫 `session.jsonl`，用文件名会把全部会话折叠成一个。ACP ID 是 `acp-v1-` + base64url(UUID)；cwd/title 也从首行和第一条 user message 恢复。
- **resume 靠把第一个 `session/new` 改写成 `session/load`**：WebMux 在 `resume` argv 末尾追加 session id；`--resume` 把它塞进 `XIAOHUANXIONG_ACP_RESUME_SESSION`，proxy 只改写第一次 `session/new`，之后原样透传。
- **WebMux 的 `processExecutables` 只写 `node`**：WebMux 看的是 PTY 根进程（Martty 是 node），不要写 ACP 侧的 `xiaohuanxiong-acp` / `box-agent-acp`，否则 hybrid 判定失败。
- **登录**：`--login` 走官方桌面端的 Linux 兼容网页登录——本地 `127.0.0.1` 一次性回调 + `/authorize?login_source=desktop&desktop_callback=loopback&redirect=...&state=...`，浏览器完成后拿 code 换 token；`--login-qr` 仍保留二维码（轮询 `/login_with_qrcode_code`，仅当手机 App 有扫码时才可用）；`--login-code <code>` 走 `/login_with_authorization_code`。回调只接受本机、一次性 state（64 hex）和单个 code，页面自带 CSP。`auth.json` 用 0600 + temp+rename，只写非空字段，不打印 token；IAM token 没有 refresh token，刷新由官方 Box-Agent runtime 在请求前完成并原子回写。
- **模型选择**：box-agent 没有 `session/set_config_option`、也不返回 `configOptions`；官方桌面端用每条 `session/prompt` 的 `_meta.llm_binding` 切模型。代理在 `session/new`/`session/load` 响应里合成标准 `model` 配置项，自己应答 `session/set_config_option`，按会话记住选择（`model-selection.json`），并在 prompt 上注入 `{source: "builtin", model, contextWindow, maxTokens}`。模型目录来自 `GET /api/web/llm/v2/model_catalog`（Bearer，token 取 `auth.json`），带磁盘缓存；没有 token 时只保留配置里的默认模型。
- **过滤内部进度事件**：box-agent 把 `llm-output-*` / `turn-usage-*` / `agent-activity-*` 发成 `tool_call(update)`（无 title/status/content，`rawOutput.type` 为 `llm_output` / `turn_usage` / `agent_activity_v1`）。代理在转发前丢弃，否则 WebMux 会给每个 id 建一张空工具卡并显示 Pending；真实工具（有 title 或有 status/content）原样通过。
- **`vendorHash` 非 null**：唯一依赖是 `github.com/skip2/go-qrcode`。`versionCheckProgramArg = "--acp-proxy-version"` 是因为 `versionCheckHook` 要裸版本号，`--version` 输出带 `xiaohuanxiong-acp ` 前缀。
- 验证：`go test ./...`；`initialize` 结果应含 `sessionCapabilities.list`；把 `XIAOHUANXIONG_ACP_REAL` 指向假脚本可离线验证 `session/list` 与 `session/new` → `session/load` 改写。
