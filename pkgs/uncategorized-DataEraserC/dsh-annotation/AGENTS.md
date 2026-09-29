# dsh-annotation 打包经验

- 上游混发正式版与 `-preview.N`，且当前 pin 的 `1.4.11-preview.1` 高于最新正式版 `1.4.10`；`nix-update` 的 STABLE 偏好会过滤 preview 版造成**降级**，更新脚本必须 `extraArgs = [ "--flake" "--version" "unstable" ]`，通用规则见 `_docs/AGENTS.md` 的「DSH 插件包」一节
- Node 半边是零依赖空壳：`src/index.ts` 只导出 `name`/`apply`，由 tsc 编译成 `lib/index.js`；真实功能全在根目录 `client.js`（经 `dsh.client` 接入 DSH web）。`npm test` 的 `test/*.test.mjs` 只读 `client.js` 文本做断言、完全离线，沙箱可跑（实测 21/21）；playwright 浏览器用例（`overlay-browser.mjs`/`sidebar-browser.mjs`）不在该 glob 内，不参与 checkPhase
- 产物形态：`pnpm deploy --prod` 把 `cordis` 等 3 个生产依赖落在部署根 `$out/lib/node_modules/`，包目录自身没有 node_modules，`linkKernelNodeModules` 把包目录的 `node_modules` 整体符号链接到 kernel；整包约 400K，`.pnpm` 只剩 lock.yaml
