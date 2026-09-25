# DataEraserC 分组经验（跨包 / 跨工具）

本目录只存放**分组级经验**：同一条经验涉及多个包，或同时涉及包 + 模块 + 工具链时写在这里；只涉及单个包的写在该包目录的 `AGENTS.md` 里。

`default.nix` 里的 `{ }: { }` 是给 `helpers/group.nix` 的 `createLoadPackages` 用的占位——它把分组目录下每个非 `.nix` 条目都当包 `callPackage`，所以本目录必须能被 import；分组的 `default.nix` 再用 `removeAttrs packages [ "_docs" ]` 把它从包集合里剔除，任何工具都看不到它。

## CLIProxyAPI 家族（面板 / 内核 / GUI）

- **CLIProxyAPI 家族（面板 / 内核 / GUI）**：
  - **单文件静态站**（`vite-plugin-singlefile`，如 Cli-Proxy-API-Management-Center）：`buildNpmPackage` 只产 `dist/index.html`，需覆盖 `installPhase` 为 `mkdir -p $out; cp -r dist/. $out/`（不要走默认的 npm install hook），`env.VERSION = finalAttrs.version` 保证 `__APP_VERSION__` 不是 `dev`，并按后端约定补 `ln -s index.html $out/management.html`
  - **上游 release 挂着成品资产时另建 `<pkg>-bin` 包**（如固定文件名、不含版本号的 `management.html`）：`fetchurl`（URL 用 `${finalAttrs.version}` 插值）+ `dontUnpack = true` + `install -Dm644 $src $out/<原名>`（后端要求固定文件名时再 `ln -s` 补别名）+ `nix-update-script { }` + `sourceProvenance = [ binaryNativeCode ]`；实测 nix-update 对固定文件名资产同样会重写 `version` 行并 prefetch 新 URL 的哈希。源码构建包与 `-bin` 版并存（前者服务可复现构建/打补丁的消费者，后者服务只消费成品的场景），两者接口一致（都提供 `management.html`）就不会牵动模块
  - **EasyCLIProxyAPI 内核对接**：它按可写基准目录下 `cpa-core/cli-proxy-api`（文件名固定）是否存在判断“内核已安装”，并需要同目录 `config.example.yaml` 模板；`ln -sfn ${cliproxyapi}/bin/server <runtime>/cpa-core/cli-proxy-api` + `install -C -m644 ${cliproxyapi.src}/config.example.yaml` + 写 `cpa-gui-meta.json`（`{"version":"v<ver>",...}`）即可让它用 Nix 内核，避免其自带/下载的二进制在 NixOS 上缺 `/lib64/ld-linux-x86-64.so.2` 而 `exit status 127`（内核按 `-config <path>` 传参，`server` 与 `cli-proxy-api` 参数兼容）

## DSH 插件包（deepseek-harness 的 buildDshBundle）

- **复用 `deepseek-harness` flake 输入的 `dsh.buildDshBundle.fromPnpmWorkspace`，不要手写 DSH bundle 协议**：手写（自己装 node_modules、自己写 `nix-support/dsh-bundles.json`）极易漏掉客户端半边产物 `lib/node_modules/<pkg>/lib/client.js`（DSH web 端的插件行会直接坏掉），并把 devDependencies 打进产物；包内先 `dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;`，再取 `dshPkgs.dsh.*`
- **`fromPnpmWorkspace` 的必要参数**：项目在子目录时 `sourceRoot = "source/<子目录>"`；helper 内部自建的 `fetchPnpmDeps` 不转发 `sourceRoot`，必须自己传 `pnpmDeps = dshPkgs.dsh.fetchPnpmDeps { inherit (finalAttrs) pname version src; sourceRoot = "source/<子目录>"; fetcherVersion = 4; hash = ...; }`（否则报 `yq: ... can't open 'pnpm-lock.yaml'`）；另有 `deployPackage = "<workspace 包名>"`、`npmDeps = null` + `npmConfigHook = dshPkgs.pnpmConfigHook`（让 `buildNpmPackage` 走 pnpm）、`npmBuildScript = "prepack"`（同时构建服务端与 `lib/client.js`）
- **产物验收**：`lib/node_modules/<pkg>/lib/client.js` 必须存在、`nix-support/dsh-bundles.json` 的 `packageRoot`/`patch` 正确、`passthru.dshBundle = true` / `dshBundleHelper = "buildDshBundle"` / `runtimeDeps` 齐全；`lib/node_modules/.pnpm` 应只剩几十 KB
- **`nix-update` 必须走 flake 模式并显式给裸包名**：`buildDshBundle` 只把 `pnpmDeps` 暴露成顶层 passthru 属性（nix-update 才能刷新哈希），而本仓库更新运行器传的是分组 attrPath（`<group>.<pkg>`），nix-update 的 flake 求值只在 `flake.packages.<system>`（本仓库只放平铺名）里查，会拿到 null 报 `unsafeGetAttrPos` / `expected a set but found null`；因此写 `nix-update-script { attrPath = "<裸包名>"; extraArgs = [ "--flake" ]; }`（无输入的 legacy 求值会因包依赖 flake 输入而失败，不能省略 `--flake`）
- **meta 会被强制求值**：nix-update 读 `pkg.meta.maintainers`，而 nixpkgs 里没有 `DataEraserC` 条目，`with lib.maintainers; [ DataEraserC ]` 在 flake/legacy 两条路径都会报 `undefined variable 'DataEraserC'`；包内统一写 `maintainers = import ../maintainers.nix;`（见 `meta.maintainers` 一节）
- **依赖 flake 输入的包必须在无输入求值下「可跳过」**：`builtins.tryEval` 捕获不了类型错误（`expected a set but found null` 会直接终止整个 `helpers/update.nix` 收集，NI 更新工作流全挂），只有 `throw` 能被捕获；因此包内对 `inputs == null` 用 `throw` 给出提示，并在自有分组文件里对它套 `ifNotNUR`（NUR 机器人读仓库时不带 flake 输入）。配套改动：`flake.nix` 加 `deepseek-harness` 输入、`helpers/update.nix` 加 `inputs ? null` 并透传给 `import ../pkgs`（上游文件，迁移后会丢）、`tools/update-package` 先探测该参数是否存在再传 flake inputs（迁移后自动退回无 inputs 模式）
- **上游没声明 `dsh.bundle` 的 npm 插件要在 `postPatch` 注入声明与 patch 文件**：bundle 协议的 `resolve-dsh-bundles.mjs manifest` 对没有任何包声明 `dsh.bundle.patch` 的输出直接 `die("no package declares dsh.bundle.patch")`；部分上游（如 FlashingChen/dsh-worktree）只教用户往 profile 手动 insert，npm 包既无声明也无 patch 文件。照上游 `liang-saint-slider` 的做法在 `postPatch` 里 `cp ${./cordis.patch.yml} cordis.patch.yml`（内容即上游 README 让用户手动 insert 的那行）+ `jq '.dsh.bundle.patch = "./cordis.patch.yml" | .files = ((.files // []) + ["cordis.patch.yml"])' package.json`，`nativeBuildInputs` 加 `jq`
- **注入 `dsh.bundle` 时 `files` 白名单不能漏 patch 文件**：`npmInstallHook` 按 `npm pack` 的 `files` 白名单把包拷进 `$out/lib/node_modules/<pkg>`，且它**内部自己会跑一次 `runHook postInstall`**（即 bundle resolver 校验），发生在自定义 installPhase 后续补拷之前——patch 不在白名单里就报 `dsh.bundle.patch does not exist`（dsh-git-worktree 能过是因为上游 package.json 自己把 cordis.patch.yml 写进了 files）
- **`cp ${./file}` 从 store 拷入源码树的文件是 444 只读**：`npm pack` 拷进 `$out` 会保留该模式，installPhase 里再 `cp -r` 覆盖同名文件会 `Permission denied`；postPatch 里补一句 `chmod u+w`（经 `jq > tmp && mv` 替换过的文件自带可写位，不受影响）
- **无 `dsh.client` 半边的插件 `postInstall` 验收测 `lib/index.js`**：`lib/client.js` 只有声明了 `dsh.client` 的 bundle 才有，上面「产物验收」条目里的 client.js 检查只适用于带客户端半边的包
- **运行期要执行 git 的 bundle 声明 `runtimeDeps = [ git ]`**：`dsh-base` 只带 ripgrep/bubblewrap、kernel 只带 bashInteractive，git 不在默认运行时里（上游 `turn-rewind` 同样声明）
- **npm tarball 本身已是发布产物时不要重跑构建、也不用手写 installPhase**：上游 `prepublishOnly` 在发布前已跑过打包（如 modlens 的 `dsh/*.js` + vite 产物 `dist/main.js` 随 tarball 发布）时设 `dontNpmBuild = true` 即可；默认 `npmInstallHook` 的 `npm pack --dry-run` 按 packlist 全量拷贝，连没有 `files` 白名单的 tarball 也能整包落进 `$out/lib/node_modules/<pkg>`（作用域包是 `$out/lib/node_modules/@scope/name`），不必照搬 dsh-worktree / dsh-plugin-guard 那段手写 installPhase 循环拷贝
- **带 `bin` 字段的 bundle 会自动生成 `$out/bin/<名>`，`meta.mainProgram` 因此必填**：`npmInstallHook` 的 `nodejsInstallExecutables` 按 package.json 的 `bin` 造包装脚本（shebang 指向 nodejs-slim），仓库「有 bin 目录必须设 mainProgram」的规则随之命中，名字用 `bin` 里的命令名并在构建产物里复核
- **`linkKernelNodeModules` 会把引擎自锁版本的同名依赖换成 kernel 的大版本**：kernel 拥有 node_modules 中所有同名包，bundle 的本地副本会被 prune 后改链接到 kernel（modlens 锁 `commander ^13.1.0`，kernel 是 15.0.0；`undici` 恰好同大版本）。插件在子进程里 `spawn(process.execPath, <本包 dist/main.js>)` 跑自带引擎、依赖与插件版本锁定时，用 `linkKernelNodeModulesKeep = [ "commander" "undici" ]` 保住本地副本；`test ! -L` 这类断言必须放 `postFixup`——`postInstall` 在 installPhase 内先于 link 脚本执行，放那里恒过
- **devDeps 多的生成式 lockfile 首次构建报 `Stream error in the HTTP/2 framing layer` / `couldn't fetch ...registry.npmjs.org` 是网络抖动**：`prefetch-npm-deps` 的 FOD 要抓全平台 optional 依赖（esbuild/biome 各几十个 tarball），失败直接重跑构建即可，**不要**去改 `npmDepsHash`（哈希并没有错）
- **`buildDshBundle`（npm 版）默认 `doCheck = false`，要跑上游测试必须显式开**：构建日志里完全没有 `checkPhase` 行就是没跑测试；需在包内显式写 `doCheck = true;` 并自定义 `checkPhase = '' runHook preCheck; node --test; runHook postCheck ''`（`buildNpmPackage` 的 `npmBuildHook` 不会自动把 `scripts.test` 接进 checkPhase）。dsh-oauthpro 实测 325 个测试全过，约 6.5 分钟
- **生成式 lockfile 不要加 `--legacy-peer-deps`**：本仓库多数 DSH 插件沿用 dsh-git-worktree 的 `npmFlags = [ "--legacy-peer-deps" ]`，但当上游 `dependencies`/`devDependencies` 的 peer 链（如 `@deepseek-ai/dsh-typert-protocol` → `@deepseek-ai/cordis`）依赖 npm 7+ 的自动 peer 安装时，legacy 模式会跳过安装，`node --test` 报 `ERR_MODULE_NOT_FOUND: Cannot find package '@deepseek-ai/cordis'`（构建能过、测试才炸，且该缺失在产物里同样是运行时炸弹）。先用不带 flag 的 `npm install` 生成 lockfile 跑通测试，确认无 peer 报错后就不要加该 flag
- **上游回归门不在 `test` script 里时，checkPhase 直接跑它**：如 dsh-notify-relay 只有 `check`/`gate`/`e2e` 等自定义命令，`node .sandbox/gate.cjs` 在沙箱内约 30 秒可跑完（host/client 双语 harness、破坏性变体、loopback HTTP 投递，全离线），而 `e2e`/`live` 才需要外网——`doCheck = true` + 自定义 `checkPhase` 跑前者即可；这类 gate 往往在模块加载期就 `import '@deepseek-ai/dsh-home-paths'`/`dsh-tools`，故 lockfile 必须解析 peerDependencies（见上条）
- **上游「先打 tag、再 bump package.json」的 DSH 插件**：tag `vX.Y.Z` 的 package.json 仍是上一版（release 资产 tgz 才是 bump 后 pack 的，但不含 `.sandbox/`），所以 src 取 fetchFromGitHub tag、postPatch 用 sed 对齐 version，且 `update.sh` 生成 lockfile 前要做同一条 sed（否则 lockfile 根 version 每次更新都变），详见包内 AGENTS.md

## 生成式 Lockfile

- **脚本必须幂等**：进入包管理器之前先取 `SRC_BEFORE=$(nix build --no-link --print-out-paths ".#$UPDATE_NIX_ATTR_PATH.src")`，`nix-update "$UPDATE_NIX_ATTR_PATH" --src-only` 之后再取一次，两者相同就 `exit 0`（源码没变 → lockfile 不可能有理由变化）。否则每次更新都会让 semver 范围整体浮动、重写 lockfile 与 `npmDepsHash`，产出“版本号不变、只改哈希”的空转提交（实测 cliproxyapi-management-center 连续 4 次）并让二进制缓存反复失效。重新生成前还必须把已提交的 lockfile 复制进新源码树做种子（`cp "$SCRIPT_DIR/package-lock.json" package-lock.json`）再 `npm install`，否则已锁定的版本会无谓上浮；shebang 里的 `nodejs` 要与派生中的 `nodejs = nodejs_24` 对齐。

## Fork 特有规则（下游对上游 AGENTS.md 的差异）

以下规则仅适用于本 DataEraserC fork，不适用于上游 xddxdd/nur-packages。根目录 `AGENTS.md` 中对应位置已替换为指向本文件的引用。

### Fork 仓库管理

- **本仓库是 xddxdd/nur-packages 的 DataEraserC fork**：上游出现较大改动时（上次是上游把 nvfetcher 换掉）才从 `upstream/master` 全新重建分支，只保留 `pkgs/uncategorized-DataEraserC/`、自有模块（`modules/` 下的 `pgy`/`cpolar`/`hkdm`/`aw88399-legion-audio`/`cliproxyapi` 与 `modules/AGENTS.md`）、`AGENTS.md` 和自有工具/工作流（上游工作流原样放回 `.github/workflows/upstream/`，不启用）；缓存是 `dataeraserc.cachix.org`（`helpers/meta.nix`），CI 只构建上传自有目录里的包（`tools/build_own_cachix.py`）。**fork 自己的经验写进最近的一处 `AGENTS.md`**——`modules/AGENTS.md`（自有模块）、`pkgs/uncategorized-DataEraserC/<pkg>/AGENTS.md`（单包）、`pkgs/uncategorized-DataEraserC/_docs/AGENTS.md`（跨包/跨工具），三处都在保留范围内，改对应部分前先读；只有跨包跨工具的规则才写本文件
- **自定义包的 `update.sh` 只读 `UPDATE_NIX_ATTR_PATH`/`UPDATE_NIX_OLD_VERSION`，再调 `nix-update "$UPDATE_NIX_ATTR_PATH" --version ...`**（多 URL/哈希的多平台包自己 sed/改写后逐个 `nix store prefetch-file` 回填哈希）
- **外部 flake 输入的构建工具链与本仓库 nixpkgs 不兼容时，钉版本而不是 `follows`**：给这类输入设 `inputs.nixpkgs.follows = "nixpkgs"` 会让它用本仓库的新 nixpkgs 求值，若其工具链（如 poetry2nix 无条件向 pypa `build` 传已被 nixpkgs 移除的 `tomli` 形参）不兼容就会报 `unexpected argument`。修法是在 `flake.nix` 里把该输入的 `nixpkgs` 与其构建工具（如 `poetry2nix`）双双钉到**该输入自己 flake.lock 验证过的 commit**（固定 commit 不会被 `nix flake update` 浮动），然后 `nix flake lock` + `nix eval --raw .#<包>.drvPath` + `nix build .#<包>` 端到端验证（钉旧 nixpkgs 的产物 drv 会与该输入 standalone 构建逐字节一致，可作对照）；上游已停更的输入这种钉死是永久性的。实例：LaphaeL-aicmd（2026-09，nixpkgs `2234999` + poetry2nix `d90f9db`）
- **`tools/check_package_meta.py` 已改为单包失败不中断全仓**：worker 里任何包求值异常（外部输入坏掉等）原先会抛 `RuntimeError` 炸掉整个 multiprocessing pool，其余 1811 个包的检查结果全被掩盖；现在 `check_package` 捕获异常、打印 `check crashed: error: ...` 摘要并把该包判为失败后继续跑。定位具体出错包时用 `nix search --json . '^'` 的键逐包 `nix derivation show .#<pkg>` 扫描，**错误串必须精确匹配**（如 `unexpected argument 'tomli'`——用裸 `tomli` 子串会误报 "atom**tomli**cally" 等词命中的几十个包）

### 包元数据（维护者）

- **包含 xddxdd 或 DataEraserC，自有目录统一引用共享列表**：维护者列表至少含仓库负责人之一；nixpkgs 没有 `DataEraserC` 条目（`with lib.maintainers; [ DataEraserC ]` 求值即报 `undefined variable`，`nix-update` 与 `tools/check_package_meta.py` 都会触发），故 `pkgs/uncategorized-DataEraserC/` 的包一律写 `maintainers = import ../maintainers.nix;`（条目须含 `name` 与 `github`，且文件必须 `git add`，否则 flake 求值报 is not tracked by Git）

### AI 参与记录规范

AI 不写进 `meta.maintainers`（其语义是"谁负责、能 ping 谁"），AI 参与只用下面两个渠道，且 `passthru` 只写在迁移时会保留的 `pkgs/uncategorized-DataEraserC/` 内。

- **包级来源用 `passthru.aiProvenance`**（不进 `meta`、不影响构建）：`passthru.aiProvenance = [ { agent = "dsh"; model = "deepseek-v4-flash"; involvement = "assisted"; } ];`——`agent` 必填，`model` 确实在用时才写、无法确证就省略（不要猜），`involvement` 取 `authored`/`assisted`/`reviewed`；查询 `nix eval --json .#<pkg>.passthru.aiProvenance`
- **变更级来源用 commit trailer**：`passthru` 覆盖不到的文件（`modules/`、`update.sh`、`AGENTS.md` 等）加 `Assisted-by: dsh:deepseek-v4-flash`（`<agent>:<model>`，沿用内核 AI Coding Assistants 约定，不要用 `Co-authored-by`）
- **不要新增自定义 `meta.*` 字段**（`checkMeta = true` 会硬失败 `key '...' is unrecognized`，`passthru` 不在校验范围），并且只在实质性参与时标注（构建逻辑、模块、更新脚本标；纯机械改动不标）
