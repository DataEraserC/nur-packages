# webmux-acp

更新本包前先读 [`../_docs/webmux-codebuddy-acp-requirements.md`](../_docs/webmux-codebuddy-acp-requirements.md)，按 `WM-ACP-*` 与 `PKG-*` 逐项验收；该文件是功能与升级不变量的单一事实源。

## 定位

`webmux-acp` 复用主 `webmux` 的完整构建定义，但把 source 原子化替换为固定的匿名下游 overlay tip。该 overlay 只承载通用 external ACP、hybrid-session 修复与 ownership 治理，不携带某个 agent、wrapper 或部署的专用逻辑。两包共享 version、前端依赖和 Go vendor baseline；源码树分别是固定 upstream base 与 `downstream/ownership.json` 审计过的连续提交范围。

## 源码来源

- `webmux-acp/default.nix` 直接固定 `mzdluo123/webmux` 中可解析的匿名 overlay tip 及对应 Nix source hash，不携带本地 patch。
- 该 tip 尚未进入 upstream advertised refs；必须保留公开 fork `desktop-tools-which-may-be-useful/webmux` 的 `feat/downstream-overlay-v0.14.5` branch，使 GitHub fork network 持续保有对象。更新 pin 前用公开 HTTPS `git ls-remote --heads` 验证该 branch 精确指向 tip。
- `downstream/ownership.json` 固定 upstream base 并分类完整 `base..tip` 路径；范围内每个 commit 必须是单 parent、author/committer 均为 `anonymous <anonymous@users.noreply.github.com>`，不带协作者 trailer、私有路径或下游部署内容。
- 基线升级时在新 upstream base 上按逻辑重放连续 overlay commits、运行上游与 ownership 验证，并把新的 tip/hash 一起写入本包。
- `passthru.updateScript = null`：本包不能脱离主包单独自动更新。

## 构建测试

主包的 `subPackages = [ "cmd/webmux" ]` 会收窄默认 Go tests。本变体的 `checkPhase` 必须显式覆盖 overlay 涉及的 external ACP、terminal→chat 与 ownership internal tests、架构/doc guards 和适用 hybrid tests，不能只继承主包 check。terminal→chat 至少覆盖 opt-in 新阶段、无 capability 的 interrupt-first 旧客户端、真实 HTTP query 与 CLI 初始/回答路径。`cmd/baseline` 的 `TestFixtureIsolatesAPIGitAndRestoresEnvironment` 硬编码 `/usr/bin/env`，Nix sandbox 只跳过这一项；package 仍完整编译并运行其余 tests，registry wiring 由 assemble/API/P2P/hybrid focused tests 覆盖。

验收至少包括：

```bash
nix build -L .#webmux-acp
out=$(nix build --no-link --print-out-paths .#webmux-acp)
$out/bin/webmux --version
```

再按需求文档验证 strict loader、exact argv、startup fd 3、launcher 唯一 child/cwd、service env 持久化与同一 registry 的 constructor wiring。公开产物仍只有上游 `webmux` 主程序；包名差异不改 CLI 接口。
