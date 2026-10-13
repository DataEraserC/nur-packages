# dsh-free-search

- 上游 tag `v0.8.6` 的 `package.json` 无 `scripts` 段（无 build/test），npm tarball 即发布产物，故 `dontNpmBuild = true`
- `dsh.bundle.patch` 声明为裸 `cordis.patch.yml`，会被 bundle resolver 以 `must be relative './...' paths` 拒绝，`postPatch` 用 `jq` 规范化为 `./cordis.patch.yml`（经验见 `_docs/AGENTS.md` DSH 插件包一节）
- 测试不在 `test` script 里，是 `tools/assert-*.mjs` 共 10 个离线门（0.8.6 是 7 个，0.8.9 新增 `assert-blocked-domains`/`assert-killtree-portable`/`assert-research-call-wrappers`），`checkPhase` 直接循环 `node` 执行；`assert-vertical` 默认离线（`--live` 才联网）、`assert-weather-contract` 用 mock fetch，均可在沙箱跑
- **`assert-killtree-portable`（0.8.9 起）在沙箱里缺 `ps` 会假失败，用 `nativeCheckInputs = [ procps ]` 修**：该门用 `execSync("ps -o pid= -g ${child.pid} 2>/dev/null || true")` 数字子进程组成员，而 Nix 构建沙箱的 PATH 没有 `ps`（procps），`|| true` 把失败吞成空串 → 成员 0 个 → `起出可观测的进程组` 断言失败（日志 `FAILED: 1 of 8`，且这一门在循环中靠后，前 5 个门先通过后才炸）；本机正常 PATH 下实测 3 个成员、该门通过。修法即 `nativeCheckInputs = [ procps ]`（`procps` 同时加进函数形参列表）——nixpkgs 的 `make-derivation.nix` 只在 `doCheck = true` 时把 `nativeCheckInputs` 并入 `nativeBuildInputs'`，正好只作用于 checkPhase。**不要**改用 `doCheck = false` 或摘掉这一门跳过：它守的是「非 Windows 平台按进程组杀浏览器时不得抛 uncaughtException 带走 dsh 宿主」的 P0 回归，正是本包存在的价值
- `lib/index.js` import `@deepseek-ai/dsh-settings`/`dsh-tools`/`schemastery`：构建期由根 `node_modules`（devDeps）解析，运行期靠 `linkKernelNodeModules` 指向 kernel 解析
- `dsh.client` 声明 `platform = "web"`，`passthru.requiresWeb = true`，客户端半边验收 `lib/client.js`
