# webmux 打包经验

上游：<https://github.com/mzdluo123/webmux>（Go 后端 + Svelte/Vite 前端，前端产物以 ZIP 形式 `//go:embed` 进二进制）

## 构建结构

- **两段式构建**：`web/` 是独立前端工程，`vite build` 由 `web/scripts/embed-assets.ts` 插件把 `dist/` 压成 `dist/embed.zip`，Go 侧 `web/embed.go` 用 `//go:embed dist/embed.zip` 读它（运行期交 `zip.NewReader` 按需解压，条目路径保留 `dist/` 前缀）。因此：
  - 前端派生 `frontendDist` 只需装出 `embed.zip`，其余 `dist/` 文件对最终产物无用
  - `buildGoModule` 的 `preBuild` 把 `embed.zip` 拷进 `web/dist/` 即可，不必覆盖整个 `dist`
- **用 `pnpm exec vite build`，不要用 `pnpm run build`**：`build` 脚本是 `svelte-check --fail-on-warnings && vite build`，类型检查对产物没有贡献却成倍拖慢构建，而且上游任何 warning 都会让构建失败；上游 `make frontend` 走的也是裸 `vite build`
- **工具链版本由上游钉死**：`.nvmrc` = `26.12.1`、`package.json` 的 `packageManager` = `pnpm@12.11.2`，nixpkgs 的 `nodejs_26`（26.12.1）与之逐字一致，`pnpm_12`（12.9.0）可用——pnpm ≥ 11 的 `pnpmConfigHook` 会设 `pnpm_config_pm_on_fail=ignore`，所以 lockfile 里 `packageManagerDependencies.pnpm = 12.11.2` 的自管理切换失败也不会中断安装
- **`fetcherVersion = 4`**：pnpm 12 的 store 布局要求 v4（与 it-tools 的 pnpm 11 同代）；`vendorHash` 与 pnpm 哈希都用占位值构建、从报错的 `got:` 行取值
- **`subPackages = [ "cmd/webmux" ]` 会把 `go test` 收窄到这个包**：checkPhase 只跑 `cmd/webmux`，`internal/docguard`、`internal/archtest` 等套件不会执行。托盘/`systray`（CGO）只在 `cmd/webmux-tray`（windows）里引入，Linux 产物无 GUI 依赖
- **版本注入走 `-X main.version`**：与上游 `Makefile` 的 `LDFLAGS` 一致，`--version` 打印 `webmux <ver>`，可直接给 `versionCheckHook` 用（`versionCheckProgramArg = "--version"`）
- **`passthru.pnpmDeps` 必须指向 `let` 里的前端依赖派生**：否则 nix-update 看不到 pnpm 哈希，版本 bump 后只更新 src 哈希，构建在 pnpm 阶段失败

## 已知风险

- 本包 pnpm 依赖用 `fetcherVersion = 4`，落在 `AGENTS_downstream.md` 记录的「GHA 上 pnpm 哈希不可复现」范围内。若 auto-update 后构建报 FOD hash mismatch，在可信构建机上 `nix build .#webmux`，把报错里的 `got: sha256-…` 手工回填到 `webPnpmDeps.hash` 即可

## 本地补丁：CodeBuddy 混合会话适配器

- `codebuddy-agent.patch` 只做两件事：新增 `internal/agentprofile/codebuddy/codebuddy.go`（92 行的 adapter），并在 `internal/agentprofile/agents/agents.go` 里加一行 import、一处 `NewRegistry(...)` 参数。不碰 `internal/hybrid/` 的任何判据——早期为绕过 `session/list` 直接放宽 `eligibility.go`/`link.go` 的做法已废弃，缺口由单独的 `codebuddy-acp` 包在 CLI 外面补
- **agent 表是源码里固定的 `NewRegistry(...)` 列表，没有任何配置/插件扩展点**，所以"给 webmux 加一个 agent"在 0.12.1 上必然要改这两个文件；等这套配置用稳后再提上游 PR（上游 `internal/launch/presets.go` 已有 `CodeBuddy Code` 预设，缺的只是 hybrid 适配）
- **版本 bump 时这个补丁大概率需要重做**：`agents.go` 的 import 块与 `NewRegistry` 单行是 nix-update 之后最容易变的地方，`patch -p1` 报 hunk 失败就按 `AGENTS_downstream.md` 的「上游补丁失效时的重新生成方法」，在解包的新源码上重放这两个文件的变换再 `diff -u` 生成（注意把补丁头改回 `a/`、`b/`，新文件用 `--- /dev/null`）
- 验收：`nix build .#webmux` 后 `POST /api/launch-configs/hybrid-support` 传 `{"cmd":["codebuddy"]}` 应返回 `supported: true, agent: "codebuddy"`；完整链路（终端起会话 → 切聊天）需要 PATH 里有 `codebuddy-acp` 包

## 验收

```bash
nix build .#webmux
out=$(nix build .#webmux --no-link --print-out-paths)
$out/bin/webmux --version            # webmux 0.10.1
$out/bin/webmux version --json       # {"v":1,"version":"0.10.1","contract":1}

export HOME=$(mktemp -d)
$out/bin/webmux serve --listen 127.0.0.1:7699 &
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7699/          # 200
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7699/assets/index-*.js  # 200，证明 embed.zip 内的 dist/ 前缀与 fs.Sub 约定一致
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7699/api/health          # 401（需 token，属正常）
```
