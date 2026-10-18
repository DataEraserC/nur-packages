# Downstream (DataEraserC) Specific Rules

本文件收纳 [xddxdd/nur-packages](https://github.com/xddxdd/nur-packages) 的 DataEraserC fork 的下游经验与规则（上游仓库没有的内容）；根 [`AGENTS.md`](AGENTS.md) 保持上游原文，以最小化同步上游时的合并冲突。

- **硬规则**：根 `AGENTS.md`「工作流程」要求的『修改包后更新经验教训』，在本 fork 一律写入本文件，禁止写入根 `AGENTS.md`
- Fork 仓库管理、维护者列表、AI 参与记录等 Fork 特有规则见 [`pkgs/uncategorized-DataEraserC/_docs/AGENTS.md`](pkgs/uncategorized-DataEraserC/_docs/AGENTS.md) 中的「Fork 特有规则」章节；自有模块的规则在 [`modules/AGENTS.md`](modules/AGENTS.md)；单包经验在各包目录的 `AGENTS.md`

## 提交信息格式

- 自动化提交用 `auto: update packages`；整仓库性修复可用描述性标题，如 `Fix Hydra build failures (eval <id>)`（下游修订：上游原文此处的示例为 `Fix package evaluation errors`）

## Nix 包定义规范

### 最佳实践

- **重型 Electron 应用拆 unwrapped + wrapper 两个包，启动逻辑照抄 nixpkgs qq 做 ozone 自适应**：当本体构建极慢（大型 npm 树拼装）而启动逻辑（平台 flag、环境变量、desktop 条目）需要频繁调整时，主包只产出原始应用树（如 `$out/opt/<app>`，无 `bin/`、无 desktop 条目，`meta.mainProgram` 一并去掉——`check_package_meta.py` 只在产物存在 `bin/` 时校验它），主包的目录名与 `pname` 都带 `-unwrapped` 后缀、在包名上写明它是未包装产物（如 `lobsterai-unwrapped`），另建 `<pkg>-wrapper` 目录用 `makeWrapper` 指向主包内的可执行文件，desktop 条目与图标也放 wrapper 使 launcher 自包含；wrapper 用 `inherit (pkg-unwrapped) version;` 跟版本、`passthru.unwrapped = pkg-unwrapped` 反向引用。Wayland ozone 自适应用 nixpkgs qq 的原文：`--add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}"`——`\''${` 让 Nix 输出字面 `\${`，使展开发生在 wrapper 脚本**运行期**而非 installPhase 构建期；写成 `''${...}` 会在构建期就展开成空串、flag 静默失效。ssh/waypipe 等远程会话通常没有 `NIXOS_OZONE_WL`（sshd 不透传），需沿用显式 `--ozone-platform=wayland`（实例：lobsterai-unwrapped / lobsterai-wrapper）
- **GL/SDL 桌面应用的 GLEW 必须按会话上下文选后端，wrapper 运行期分发二进制**：GLEW 默认 GLX 构建（`glXGetProcAddress` 取入口）在 Wayland 会话下必挂——SDL3 在 Wayland 只创建 EGL 上下文，`glewInit` 报 `Missing GL version`（glGetString 走 EGL 通用 stub 拿不到版本串）或 `Unknown error`；改开 `GLEW_EGL=ON`（经 cmake initial-cache 传入 `-C` 文件即可，CMake 变量跨语言包照常生效）后 X11 的 GLX 上下文又挂——后端 × 上下文四种组合只有同后端成立，而 SDL3 按会话自动选驱动（Wayland 会话默认 wayland、X11 会话默认 x11），构建期不可知该配哪种。SDL2 遗留的 `SDL_VIDEO_X11_FORCE_EGL` 在 SDL3 实测不生效，全局 `SDL_VIDEO_FORCE_EGL=1` 能让单 EGL 二进制双腿可用（实测过），但它只是环境变量、用户可覆盖。可靠做法：同一配方出两个 unwrapped 变体（`glewEgl ? false` 参数化、变体 pname 加 `-egl` 后缀），wrapper 用 `--run` 按 `${SDL_VIDEODRIVER:-}` 首选驱动加 `${WAYLAND_DISPLAY}` 存在性 `exec` 对应二进制，其余环境全量透传（实例：BongoCat 的 GLX/EGL 双变体）。验证必须 `SDL_VIDEODRIVER=wayland` 与 `SDL_VIDEODRIVER=x11` 各实跑一次到 `Startup ready`，单腿绿不代表可用
- **`POST_BUILD` 拷到 build 目录旁的运行期资源必须在 `installPhase` 一并安装**：为构建期测试拷出的资源，产物里不会自动带上，构建照常成功、运行期静默失效（实例：BongoCat 的 Cubism `FrameworkShaders` 只 `cp` 进 build 目录时，二进制旁缺文件，每次启动刷上百行 shader 加载失败日志、模型加载报 0x501）
- **NixOS 无 `/usr/share/fonts`，自绘 UI 硬编码 FHS 字体候选会让 CJK 页面整页空白**：Nuklear/stb_truetype 一类自绘 UI 常把 Linux 字体候选写死为 `/usr/share/fonts/...` 绝对路径（无 fontconfig/XDG/环境变量逃逸），NixOS 上全部 `readable()` 落空 → 回退 Nuklear 内置默认字体（仅拉丁字形）→ 切换中文等 CJK 语言后每个标签绘空，表现为「设置页不显示」。修法：`postPatch` 用 `substituteInPlace` 把 nixpkgs 字体的 store 路径插进候选数组（实例：BongoCat 注入 `lxgw-neoxihei` 的 `share/fonts/truetype/LXGWNeoXiHei.ttf`）；二进制内的 store 路径字符串会被 fixup 引用扫描自动拉进闭包，buildInputs 再列一份更可读。**选字体必须 TrueType glyf 轮廓**：stb_truetype 烘不出 CFF/OpenType-PS，`noto-fonts-cjk-sans`（`NotoSansCJK-VF.otf.ttc`，CFF）不可用，`lxgw-neoxihei`/`wqy_zenhei` 实测 glyf 可用；替换锚点选以 `",` 结尾的候选行可同时命中正文与粗体两处、又天然排除以 `"};` 结尾的韩文分支。验证用上游 CI 旗标 `--ci-smoke --ci-preferences --ci-language=zh-CN`，读状态文件 `ui-frame.txt` 的 `font_path/font_file/font_probe` 全 1 且 `valid=1` 即过。测试机械注意：`SDL_GetWindowID` 的值**不是** X11 XID（`preferences-window.txt` 里存的是 SDL id，直接喂 `import` 会失败且该进程报错后可能睡死，外面必须套 `timeout`），真 XID 用 `xdotool search` 枚举、按 `getwindowgeometry` 尺寸挑设置窗（对 612x536 的猫窗认 1800x1360）；`--ci-smoke` 下应用约 3 秒自退（实测），截图必须 `--ci-exit-ms=` 拉长存活期

- **Bun 编译的单文件可执行不能 strip**：Bun 把业务 JS 作为 payload 放在 ELF 段之外（`codebuddy`/`codearts` 的原生发布物都是这种 150MB 左右的二进制）。stdenv fixupPhase 默认的 `strip` 会删掉 payload，二进制退化成裸 Bun CLI：`--version` 打印 Bun 帮助而不是应用版本，versionCheckHook 随之失败。必须 `dontStrip = true;`；`patchelf --set-interpreter`/autoPatchelfHook 本身不会破坏 payload。排查特征：versionCheckPhase 输出一大段 `bun install --help`（实例：codebuddy / codearts）
- **`helpers/update.nix` 的 `usesSources` 启发式会误伤多源包**：它读 `meta.position` 指向的文件内容，只要出现 `sources.` 子串（包括 `builtins.readFile ./sources.json` 这种文件名引用）就把整包从更新列表里跳过，`passthru.updateScript` 永远不会执行。多平台预编译包若用自定义 `update.sh` 维护哈希，把 JSON 命名为 `release.json`（绑定叫 `release`）即可规避，不必放弃自定义更新脚本（实例：codebuddy / codearts / workbuddy）

## updateScript 包更新机制（nixpkgs 风格）

- **更新脚本只在版本变化时写哈希 = 既有哈希永远不被校验**：上游内容漂移（如旧 tag 上新增 `.gitmodules`、re-tag）或脚本自身写错哈希都不会被更新流程发现，只有等 Hydra 构建失败才暴露。写哈希的脚本必须在写入后（或每次运行时对易错条目）做一次真实构建验证，把哈希错误挡在提交之前，而不是依赖 CI 构建兜底（下游修订：上游原文此处为「只有等构建失败才暴露」）
- 下游修订：「多源包的 sources.json 模式」一节的示例包列表在本 fork 含 `lantianCustomized.nginx`（上游原文示例为「fr24feed、dbip-lite、qemu-user-static、qq」）

## 源码管理

- 多源包使用 `sources.json` + `importJSON`/`fromJSON`（如 fr24feed、qemu-user-static、lantianCustomized.nginx），由包内 `update.sh` 整体重写（下游修订：上游原文此处的示例列表不含 `lantianCustomized.nginx`）

## Hydra 构建失败修复

当被要求修复 Hydra 构建失败时，按以下流程执行：

1. 访问 <https://hydra.lantian.pub/jobset/lantian/nur-packages>，进入最近一次构建（latest build）
2. 从该构建的 job 列表中找出所有失败的包
3. 逐个修复失败的包

不要凭猜测或历史构建判断失败项，一律以该 jobset 的最新构建为准。

### 必须同时检查评估错误

「Hydra 构建失败」包含两类失败，二者都要修：

- **评估错误（eval errors）**：求值阶段就失败的 job（如引用了已删除/改名的 nixpkgs 属性、`throw` 等），它们在 job 列表里根本不出现或只显示为空，只会出现在 jobset 的 Errors 标签页。**这类错误不会出现在构建失败列表里，容易漏修**。
- **构建失败（build failures）**：求值成功但构建失败的 job（`Failed` / `Dependency failed`）。

取完整失败清单的方法：

- 评估错误：取 <https://hydra.lantian.pub/jobset/lantian/nur-packages> 页面里最新的 eval id（`latest-eval`），再打开 `https://hydra.lantian.pub/eval/<id>/errors?full=1`。
- 构建失败：`https://hydra.lantian.pub/eval/<id>/builds`（`Accept: application/json`）返回该 eval 的全部 build，`buildstatus` 非 0 的即失败（1=Failed，2=Dependency failed）。jobset 页面默认的 Jobs 标签页只列 canonical 名，`uncategorized-` 等别名 job 会被漏掉。
- 依赖失败要顺着 `it-tools: Dependency failed` 之类的行找到真正失败的依赖 build 日志（`https://hydra.lantian.pub/build/<id>/nixlog/<n>` 会重定向到出错依赖的 drv 日志）。

### 已知易错点：fetchPnpmDeps 哈希在 GitHub Actions 上不可复现

it-tools 的 `pnpmDeps` 哈希会被 auto-update 反复改错（`ba9c1129` 手工修正后 `6362f6d4` 又改回错误值）。已定位为 **GHA runner 环境导致的 pnpm store 生成竞态**，不是 nixpkgs 版本差异：

- 从 GHA auto-update run 日志（`gh run view <id> --repo xddxdd/nur-packages --log`）确认该 run 用 `NIX_PATH=nixpkgs=channel:nixos-unstable`，而 `channels.nixos.org/nixos-unstable/git-revision` 当时和现在都是 `a7868a7…`，即与 flake.lock 钉住的 nixpkgs 完全相同。
- 用 channel a7868a7（默认 config）和 flake（带 allowUnfree 等 config）分别求值 `it-tools.pnpmDeps.drvPath`，得到同一个 drv `42x3kyifb9ds…`。同一个 drv、同一个 pnpm 11.27.0 / node 24.21.0 / sqlite 3.53.3，GHA 算出 `sha256-qfoBr6…`，兰天构建机算出 `sha256-Qn2DCJ…`。
- 即纯粹是构建环境/时序差异（nixpkgs issue #422889、#484013），GHA 产物在 hash mismatch 后即被丢弃，不在任何 store/cache 里，无法事后 diff。

**实测只影响 `fetcherVersion = 4`（pnpm 11）：**

- it-tools 用 `pnpm_11` + `fetcherVersion = 4`，GHA 与兰天哈希不一致，已实测复现。改用 `pnpm_10` + `fetcherVersion = 3` 不可行：it-tools 的 lockfile（pnpm 11 生成）在 `patchedDependencies:` 里存的是 pnpm 11 的补丁哈希，pnpm 10.34.5 校验时报 `ERR_PNPM_LOCKFILE_CONFIG_MISMATCH`。因此 it-tools 保持 `nix-update-script { extraArgs = [ "--src-only" ]; }`，auto-update 只更新 version/src，**不写 GHA 上算出的 pnpmDeps 哈希**；版本升级后哈希变旧、Hydra 报 FOD hash mismatch，需在可信构建机上手工刷新。
- axonhub 用 `pnpm_10` + `fetcherVersion = 3`，不受影响：GHA 算出的 `sha256-Juge/qz…` 与本地/远程构建机一致（pnpm 10.34.5 已含 10.29.0 的 `initStore` 修复）。历史上 axonhub 出现过的 vendorHash 被污染是 `passthru.pnpmDeps` 缺失导致的字段错位（见 commit `0aa06b4a`，由 `75b86aff` 修复），与哈希不可复现无关。因此 axonhub 保持普通 `nix-update-script { extraArgs = [ "--version" "unstable" ]; }`。
