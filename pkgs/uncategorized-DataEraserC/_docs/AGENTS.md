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

## 生成式 Lockfile

- **脚本必须幂等**：进入包管理器之前先取 `SRC_BEFORE=$(nix build --no-link --print-out-paths ".#$UPDATE_NIX_ATTR_PATH.src")`，`nix-update "$UPDATE_NIX_ATTR_PATH" --src-only` 之后再取一次，两者相同就 `exit 0`（源码没变 → lockfile 不可能有理由变化）。否则每次更新都会让 semver 范围整体浮动、重写 lockfile 与 `npmDepsHash`，产出“版本号不变、只改哈希”的空转提交（实测 cliproxyapi-management-center 连续 4 次）并让二进制缓存反复失效。重新生成前还必须把已提交的 lockfile 复制进新源码树做种子（`cp "$SCRIPT_DIR/package-lock.json" package-lock.json`）再 `npm install`，否则已锁定的版本会无谓上浮；shebang 里的 `nodejs` 要与派生中的 `nodejs = nodejs_24` 对齐。
