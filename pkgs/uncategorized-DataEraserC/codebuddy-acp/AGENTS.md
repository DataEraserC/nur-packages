# codebuddy-acp

更新本包或 WebMux/nix-config 接线前，先按 [`../_docs/webmux-codebuddy-acp-requirements.md`](../_docs/webmux-codebuddy-acp-requirements.md) 的 `CB-*` 及相关 `PKG-*`/`NC-*` 需求逐项验收；该文档是产品与迁移不变量的单一事实源。

- **唯一安装入口是 `codebuddy-acp`，不要影子化 `codebuddy`**：裸运行 `codebuddy-acp`（以及任何不选择 stdio ACP 的参数）必须用 `syscall.Exec` 原样进入 vendor CodeBuddy，保留 TUI、`--print` 和其它 CLI 行为；只有 `--acp`（默认 stdio，或显式 `--acp-transport stdio`）才启动本包的专用 ACP stdio proxy。`--acp` 与 transport 参数的先后顺序不影响选择，非 stdio 或缺失 transport 值不得误入 stdio proxy。
- **WebMux 的“通用 ACP”是外部命令接入契约，不是跨 agent proxy**：由 WebMux 配置外部 ACP 可执行文件与其 ACP 参数；CodeBuddy 的缺口仍由本包这个专用 proxy 补齐，不把它扩展成代理其它 agent 的通用服务。
- **入口分发保留可测试 seam**：非 ACP 路径通过注入的 exec 函数测试真实 binary、原始 `argv[0]`、其余 argv 与环境原样透传；ACP 路径同样注入 serve 函数测试不发生 exec。Nix 配方显式在 `checkPhase` 运行 `go test -race ./...`，使这些契约与并发安全进入 `nix build .#codebuddy-acp`
- **协议状态必须属于一次 serve，client stdout 必须只有一个加锁 writer**：client→vendor 与 vendor→client 在不同 goroutine；initialize ID 不能是包级全局变量，本地 `session/list` 与 vendor frame 必须共用同一个原子 writer，否则 race detector 会报竞争且两条 JSON 行可能交织。vendor stdout 先 EOF 时要关闭 client reader 与 child stdin 后 `Wait`，不能等待仍打开的 client stdin
- **`session/list` cursor 是不透明 token**：超过单页上限时返回 `nextCursor`，后续请求按它继续；cwd 从 transcript 内容恢复，省略 cwd 时扫描当前 CodeBuddy profile 的全部项目。显式 `CODEBUDDY_CONFIG_DIR` 即使尚无 `projects/` 也不能回退默认 profile
