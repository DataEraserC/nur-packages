# webmux-acp

更新本包前先读 [`../_docs/webmux-codebuddy-acp-requirements.md`](../_docs/webmux-codebuddy-acp-requirements.md)，按 `WM-ACP-*` 与 `PKG-*` 逐项验收；该文件是功能与升级不变量的单一事实源。

## 定位

`webmux-acp` 是主 `webmux` 的同基线 patched variant。它只叠加通用外部 ACP command declaration，不携带某个 agent、wrapper 或部署的专用逻辑。主包与本包必须共享完全相同的源码、前端依赖和 Go vendor 基线。

## 补丁来源

- `patches/external-acp-agents.patch` 必须由固定基线之上的**一个**匿名 WebMux commit 通过 `git format-patch` 导出；不要手工改补丁正文。
- 该 commit 可以推到获准的公共分支；author/committer 保持仓库局部身份 `anonymous <anonymous@users.noreply.github.com>`，不带协作者 trailer、私有路径或下游部署内容。
- 基线升级时在新基线上重放该单 commit、运行上游验证并重新导出；用 patch dry-run 和 tree diff 证明导出物等价。
- `passthru.updateScript = null`：本包不能脱离主包单独自动更新。

## 构建测试

主包的 `subPackages = [ "cmd/webmux" ]` 会收窄默认 Go tests。本变体的 `checkPhase` 必须显式覆盖补丁涉及的 internal packages、架构/doc guards 与适用 hybrid tests，不能只继承主包 check。`cmd/baseline` 的 `TestFixtureIsolatesAPIGitAndRestoresEnvironment` 硬编码 `/usr/bin/env`，Nix sandbox 只跳过这一项；package 仍完整编译并运行其余 tests，registry wiring 由 assemble/API/P2P/hybrid focused tests 覆盖。

验收至少包括：

```bash
nix build -L .#webmux-acp
out=$(nix build --no-link --print-out-paths .#webmux-acp)
$out/bin/webmux --version
```

再按需求文档验证 strict loader、exact argv、startup fd 3、launcher 唯一 child/cwd、service env 持久化与同一 registry 的 constructor wiring。公开产物仍只有上游 `webmux` 主程序；包名差异不改 CLI 接口。
