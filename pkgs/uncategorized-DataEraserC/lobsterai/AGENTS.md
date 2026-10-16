# lobsterai 打包经验

LobsterAI（网易有道，MIT）是 Electron 43 桌面应用，Linux 侧**上游完全不发布产物**：更新接口 `api-overmind.youdao.com/openapi/get/luna/hardware/lobsterai/prod/update` 只有 `windowsX64`/`macIntel`/`macArm` 三个 key，GitHub releases 也没有资产（issue #273 正是在要 Linux 版），CI 虽然 `electron-builder --linux` 但产物不发布。因此只能源码构建，且必须自己补齐上游 `dist:linux` 里被省略的部分。

## 派生结构

- `default.nix`（`lobsterai`）：`build` → `tsc` + 双 vite + `compile:electron`，然后手工拼装目录而不是跑 electron-builder（避免 AppImage/deb 工具链与 electron 下载），用 nixpkgs `electron_43.dist`。
- `openclaw-runtime.nix`（`lobsterai-openclaw-runtime`）：从 openclaw 源码打 64 个补丁构建 cfmind 运行时。
- `mkSkill`（文件内 let 绑定）：`web-search` / `pptx` / `imap-smtp-email` 三个技能各自一个 FOD + 小派生。

## 关键坑

- **`npmConfigHook` 不是 pkgs 顶层属性**，`callPackage` 直接声明会报 `Function called without required argument "npmConfigHook"`（提示里会误导向 `pnpmConfigHook`）。正确写法是声明 `npmHooks` 并用 `npmHooks.npmConfigHook`。
- **structuredAttrs 下顶层属性和 `env.*` 都会被导出**（实测 `runCommand { __structuredAttrs = true; env.BAR=...; TOPLEVEL=...; }` 两者都能读到）。所以 `npmDeps` 再写一份 `env.npmDeps` 会直接报 `The env attribute set cannot contain any attributes passed to derivation`；两者二选一即可，取顶层写法（同时是构建输入、nix-update 也读得到）。
- **上游不提交任何 lockfile**（LobsterAI 根目录、`SKILLs/*` 都没有），全部自行用 `npm install --package-lock-only` 生成后入库；`fetchNpmDeps` 用 `postPatch` 把 vendored lockfile 拷进源码树（官方 hint 就是这么写的），并且主派生的 `postPatch` 也要拷同一份，`npmConfigHook` 会 diff 两边是否一致。
- **技能依赖不是由 `build:skills` 装的**：那个脚本只管 web-search/tech-news/email。真正装全的是 `scripts/electron-builder-hooks.cjs` 的 `beforePack`，它遍历 `SKILLs/*/package.json` 逐个 `npm install`（实测产物里有 node_modules 的是 `web-search` 34M、`pptx` 37M、`imap-smtp-email` 7.3M）。`pptx` 依赖 `playwright`，其 postinstall 会拉浏览器，Nix 里走 `npm ci --ignore-scripts`（与实测产物一致：里面也没有浏览器）。
- **`build-openclaw-runtime.sh` 第 5 步会 `rm -rf node_modules package-lock.json` 再跑无 lockfile 的网络 `npm install --omit=dev`**，沙箱里必挂。用 `openclaw-runtime-offline.patch` 改成保留 lockfile，并在 `pack-openclaw-workspace-deps.cjs` 之后 `cp` 进打包态的 `cfmind-package.json` / `cfmind-package-lock.json` 再 `npm ci`。这两个文件是从一次成功构建的 `resources/cfmind/` 里取出来的**最终状态**（已含 workspace 依赖被改写成 `file:workspace-packages/*.tgz`、已删 devDependencies、已加 `@opentelemetry/api`），`pack-openclaw-workspace-deps.cjs` 必须先跑，否则那个 `file:` tarball 不存在。
- **openclaw 源码树必须 `git init` + commit**：`apply-openclaw-patches.cjs` 末尾会对 openclaw 源码跑 `git reset HEAD .`，fetchFromGitHub 的产物没有 `.git` 会失败。
- **openclaw 的 control-ui 构建不可字节复现**：连续两次构建有 1130 处差异，全部是 `assets/*-<hash>.js` 的 chunk 名不同，把 8 位 hash 归一化后内容完全一致。因此**不能**把整个 cfmind 构建包成固定输出派生（输出永远对不上声明哈希），只能是普通输入寻址派生。
- **`npmRoot` 不能写 `$NIX_BUILD_TOP/...` 这种要展开的变量**：钩子里是 `pushd "$npmRoot"`，bash 不会二次展开，必须写成相对源码根的路径（`../lobsterai`）。
- **dsh 运行时在 Linux 上根本没有**：`package.json` 的 `dsh.runtimes` 只有 mac-arm64/mac-x64/win-x64 三个 URL，实测产物 `resources/` 里也没有 dsh 目录；`dshEngineManager` 找不到运行时只 `console.warn` 后降级，不影响启动。所以不打包 dsh（早期的 `dsh-runtime.nix` 只解压 16KB 的 npm tarball、不装 72 个依赖，是坏的，已删除）。
- **Electron 侧不用 asar**：手工拼装用 `resources/app/` 目录，`electron-builder.json` 里那几个 `asarUnpack`（`better-sqlite3`/`@img`/`npm`）自然就不需要了。`better-sqlite3` v13 自带全平台 `prebuilds/linux-x64.node`，`hasInstallScript` 为假，不编译。
- **`process.resourcesPath` 取决于可执行文件位置**：`electron_43.dist`（即 `$electron/libexec/electron`，已 patchelf）整个拷到 `$out/opt/lobsterai/` 后必须把里面的 `electron` 改名成 `LobsterAI`，否则它会指向 nixpkgs electron 自己的 resources 目录，`cfmind`/`SKILLs` 全找不到。
- **修 `dontStrip = true` 和 `dontPatchELF = true`**：fixup 的 `patchelf --shrink-rpath` 会删掉 `$ORIGIN` 相对 rpath，把 electron 与 native `.node` 模块打坏。
- **native `.node` 模块缺 `libstdc++.so.6`，要在 wrapper 里补 `LD_LIBRARY_PATH`**：手工拼装的 electron 不走 `autoPatchelfHook`，cfmind 运行时里的 linux glibc `.node`（better-sqlite3、tree-sitter 系等 7 个）直接 `ldd` 报 `libstdc++.so.6 => not found`，有模块还要求 `GLIBCXX_3.4.32`（实测 gcc-13 libstdc++ 最高 3.4.32 恰好够、gcc-15 到 3.4.34 更稳，主包自己的 12 个 `.node` 只要 3.4.29）。修法：`makeWrapper … --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}"`——wrapper 环境变量会被 Electron spawn 出的 cfmind gateway 子进程继承，一处覆盖主进程与运行时。排查手法：`find <out> -name '*.node' | grep -Ev 'musl|darwin|win32|arm'` 逐个 `ldd | grep 'not found'`、`readelf --version-info` 取所需 `GLIBCXX_*` 最高版再对 gcc-lib 各版本的 `strings` 产出。
- **`registry.npmjs.org` 的 `@img/*` 系列 tarball 走 HTTP/2 偶发 `Stream error in the HTTP/2 framing layer`**，构建会报 `builder failed`，重试即可，不是哈希问题。

## `fetchPnpmDeps` 的产物形态

`fetchPnpmDeps` 的 FOD 输出目录里**只有两个条目**：`.fetcher-version`（内容就是版本号）和 `pnpm-store.tar.zst`（整个 pnpm store 的可复现 tarball）。tar 内部是 `./v11/files/<sha512 前两位>/<hash>` 的内容寻址布局；`fetcherVersion = 4` 时 SQLite 的 `v11/index.db` 会被 dump 成 `v11/index.db.sql`（二进制 SQLite 格式不确定，nixpkgs 刻意转成 SQL 文本，再把 `,x'` 换回 `,X'` 以兼容 sqlite 3.53.0 之前的表示）。派生用 `pnpm_12` 时产物**仍是 `v11/`**（不是 `v12/`），所以 nixpkgs fixup 阶段硬编码的 `{v3,v10,v11}` 够用。tar 的可复现参数为 `--sort=name --mtime=@$SOURCE_DATE_EPOCH --owner=0 --group=0 --numeric-owner --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime --zstd`。注意 openclaw 的 lockfile 覆盖全平台（`@anthropic-ai/claude-agent-sdk-*`、`@github/copilot-*`、`@rolldown/binding-*` 等各平台二进制，单个可到 185MB），这个 FOD 下载量极大，首次构建耗时以十分钟计。

## 环境层面的坑（本机踩过，换机器先自查）

- **只读 store 里残留的空 FOD 输出目录会永久堵死该输出路径**：`/nix/store/bg2jq9h4y…-lobsterai-openclaw-runtime-pnpm-deps` 是个 0 字节、`nobody:nogroup` 所有的空目录（外加同名 `.lock`），而 `/nix/store` 对非受信用户是 `Read-only file system`，删不掉。症状很典型：drv 已进入 `building …`，但 `.chroot` 恒为 0 字节、构建器日志一个字节都不出。FOD 的输出路径由 `name + outputHash` 决定，因此**换掉占位哈希（或换 pname）就能换到一条全新且干净的输出路径**——这是绕过，不是修复。
- **`builtins.getFlake (toString <仓库>)` 走 `path:` 语义，会把未跟踪的巨型目录一起拷进 store**：本仓库里 `.tmp-lobsterai` 有 16G，探针表达式里这样引用仓库时 Nix 会尝试拷整棵树并报 `No space left on device`。而 `nix build .#…` 对 git 仓库走 git 语义、只取已跟踪文件（本仓库仅 731 个），又快又不炸。**写探针表达式不要用 `getFlake` 指向仓库，直接 `nix build .#`**；`openclaw-runtime.nix` 这类辅助文件不单独暴露成 flake 属性，要靠构建依赖它的 `lobsterai` 来触发其 FOD。
- **非受信用户（`nix store ping` 报 `Trusted: 0`）改不了 `substituters`**，`--option substituters` 属受限设置会被忽略；若 `~/.cache` 又是只读挂载，`fetcher-cache-v4.sqlite` 写不进去，每次 `nixpkgs#…` 都会去重拉 flake registry——registry 源不可达时这类解析彻底失败，只能靠 `flake.lock` 锁定的 nixpkgs 走 `.#`。同理，`/nix/store/*.lock` 与 store 内残留产物也清不掉。
