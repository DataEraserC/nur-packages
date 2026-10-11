# dsh-free-search

- 上游 tag `v0.8.6` 的 `package.json` 无 `scripts` 段（无 build/test），npm tarball 即发布产物，故 `dontNpmBuild = true`
- `dsh.bundle.patch` 声明为裸 `cordis.patch.yml`，会被 bundle resolver 以 `must be relative './...' paths` 拒绝，`postPatch` 用 `jq` 规范化为 `./cordis.patch.yml`（经验见 `_docs/AGENTS.md` DSH 插件包一节）
- 测试不在 `test` script 里，是 `tools/assert-*.mjs` 共 7 个离线门，`checkPhase` 直接循环 `node` 执行；`assert-vertical` 默认离线（`--live` 才联网）、`assert-weather-contract` 用 mock fetch，均可在沙箱跑
- `lib/index.js` import `@deepseek-ai/dsh-settings`/`dsh-tools`/`schemastery`：构建期由根 `node_modules`（devDeps）解析，运行期靠 `linkKernelNodeModules` 指向 kernel 解析
- `dsh.client` 声明 `platform = "web"`，`passthru.requiresWeb = true`，客户端半边验收 `lib/client.js`
