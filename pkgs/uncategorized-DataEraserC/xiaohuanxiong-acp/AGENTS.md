# xiaohuanxiong-acp

Raccoon Work 的 ACP 桥 + Martty 终端 UI。安装 `xiaohuanxiong-acp`，另有 `xiaohuanxiong-acp-resume` 符号链接（`argv[0]` 以 `-resume` 结尾时自动补 `--resume`）。

- **状态目录**：`BOX_AGENT_HOME` 优先；`MULTI_INSTANCE` 下用 `$HOME/.box-agent`，否则 `$XDG_STATE_HOME/xiaohuanxiong-acp/box-agent`。`BOX_AGENT_CONFIG_DIR` / `MARTTY_HOME` 默认在其下；`prepareState` 建 0700 目录并 seed 一次 `config.yaml`。桌面 `xiaohuanxiong` 也用 `~/.box-agent`，但 multi-instance 的 `stateDirectoryKey` 不同，互不影响。
- **`session/list` 的 UUID 必须从首行 `type == "session"` 记录取，不能用文件名**：Box-Agent 所有 transcript 都叫 `session.jsonl`，用文件名会把全部会话折叠成一个。ACP ID 是 `acp-v1-` + base64url(UUID)；cwd/title 也从首行和第一条 user message 恢复。
- **resume 靠把第一个 `session/new` 改写成 `session/load`**：WebMux 在 `resume` argv 末尾追加 session id；`--resume` 把它塞进 `XIAOHUANXIONG_ACP_RESUME_SESSION`，proxy 只改写第一次 `session/new`，之后原样透传。
- **WebMux 的 `processExecutables` 只写 `node`**：WebMux 看的是 PTY 根进程（Martty 是 node），不要写 ACP 侧的 `xiaohuanxiong-acp` / `box-agent-acp`，否则 hybrid 判定失败。
- **登录**：`--login` 打二维码并轮询 `/login_with_qrcode_code`；`--login-code <code>` 走 `/login_with_authorization_code`。`auth.json` 用 0600 + temp+rename，只写非空字段，不打印 token；access/refresh token 的刷新由官方 Box-Agent runtime 在请求前完成并原子回写。
- **`vendorHash` 非 null**：唯一依赖是 `github.com/skip2/go-qrcode`。`versionCheckProgramArg = "--acp-proxy-version"` 是因为 `versionCheckHook` 要裸版本号，`--version` 输出带 `xiaohuanxiong-acp ` 前缀。
- 验证：`go test ./...`；`initialize` 结果应含 `sessionCapabilities.list`；把 `XIAOHUANXIONG_ACP_REAL` 指向假脚本可离线验证 `session/list` 与 `session/new` → `session/load` 改写。
