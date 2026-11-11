# webmux 打包经验

更新 WebMux 基线、updater 或 `webmux-acp` 补丁前，先按 [`../_docs/webmux-codebuddy-acp-requirements.md`](../_docs/webmux-codebuddy-acp-requirements.md) 的 `WM-ACP-*` 与 `PKG-*` 逐项验收；该文档是跨包/跨仓需求的单一事实源。

上游：<https://github.com/mzdluo123/webmux>（Go 后端 + Svelte/Vite 前端，前端产物以 ZIP 形式 `//go:embed` 进二进制）

## 构建结构

- **两段式构建**：`web/` 是独立前端工程，`vite build` 由 `web/scripts/embed-assets.ts` 插件把 `dist/` 压成 `dist/embed.zip`，Go 侧 `web/embed.go` 用 `//go:embed dist/embed.zip` 读它（运行期交 `zip.NewReader` 按需解压，条目路径保留 `dist/` 前缀）。因此：
  - 前端派生 `frontendDist` 只需装出 `embed.zip`，其余 `dist/` 文件对最终产物无用
  - `buildGoModule` 的 `preBuild` 把 `embed.zip` 拷进 `web/dist/` 即可，不必覆盖整个 `dist`
- **用 `pnpm exec vite build`，不要用 `pnpm run build`**：`build` 脚本是 `svelte-check --fail-on-warnings && vite build`，类型检查对产物没有贡献却成倍拖慢构建，而且上游任何 warning 都会让构建失败；上游 `make frontend` 走的也是裸 `vite build`
- **工具链版本由上游钉死**：`.nvmrc` = `26.13.0`、`package.json` 的 `packageManager` = `pnpm@12.18.0`，nixpkgs 的 `nodejs_26`（26.13.0）与之逐字一致，`pnpm_12`（12.9.0）可用——pnpm ≥ 11 的 `pnpmConfigHook` 会设 `pnpm_config_pm_on_fail=ignore`，所以 lockfile 里的 pnpm 自管理切换失败也不会中断安装
- **`fetcherVersion = 4`**：pnpm 12 的 store 布局要求 v4（与 it-tools 的 pnpm 11 同代）；`vendorHash` 与 pnpm 哈希都用占位值构建、从报错的 `got:` 行取值
- **`subPackages = [ "cmd/webmux" ]` 会把 `go test` 收窄到这个包**：checkPhase 只跑 `cmd/webmux`，`internal/docguard`、`internal/archtest` 等套件不会执行。托盘/`systray`（CGO）只在 `cmd/webmux-tray`（windows）里引入，Linux 产物无 GUI 依赖
- **版本注入走 `-X main.version`**：与上游 `Makefile` 的 `LDFLAGS` 一致，`--version` 打印 `webmux <ver>`，可直接给 `versionCheckHook` 用（`versionCheckProgramArg = "--version"`）
- **快照更新需组合两步**：上游同时有 `dev` 与 `v*` tag，`unstableGitUpdater` 必须用 `tagFormat = "v*"` 和 `tagPrefix = "v"`，先更新 version/rev/src hash；随后运行 `nix-update --version skip --no-src` 刷新 Go `vendorHash` 与公开的 `passthru.pnpmDeps` hash。只运行前一步会留下不可构建的依赖哈希
- **`passthru.pnpmDeps` 必须指向 `let` 里的前端依赖派生**：否则 nix-update 看不到 pnpm 哈希，版本 bump 后只更新 src/vendor 哈希，构建在 pnpm 阶段失败

## 已知风险

- 本包 pnpm 依赖用 `fetcherVersion = 4`，落在 `AGENTS_downstream.md` 记录的「GHA 上 pnpm 哈希不可复现」范围内。若 auto-update 后构建报 FOD hash mismatch，在可信构建机上 `nix build .#webmux`，把报错里的 `got: sha256-…` 手工回填到 `webPnpmDeps.hash` 即可

## 验收

```bash
nix build .#webmux
out=$(nix build .#webmux --no-link --print-out-paths)
$out/bin/webmux --version            # webmux 0.14.4-unstable-2026-11-11
$out/bin/webmux version --json       # {"v":1,"version":"0.14.4-unstable-2026-11-11","contract":1}

export HOME=$(mktemp -d)
$out/bin/webmux serve --listen 127.0.0.1:7699 &
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7699/          # 200
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7699/assets/index-*.js  # 200，证明 embed.zip 内的 dist/ 前缀与 fs.Sub 约定一致
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:7699/api/health          # 401（需 token，属正常）
```
