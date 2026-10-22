# dsh-headless-display 打包笔记

上游：<https://github.com/jingyingruodi/dsh-headless-display>（MIT，Cordis bundle）。
锁定 tag `v1.4.1`（2026-10-21，HEAD `209c2f6`），用 `nix-update --flake` 随 tag 更新。

## 零依赖 bundle 的装配方式

上游 `package.json` **没有** `dependencies` / `peerDependencies` / `devDependencies`，
也**没有** `package-lock.json`（纯 JS，只用 node 内置模块）。因此：

- `npmDeps = null;` + `npmConfigHook = pkgs.emptyDirectory;` —— 必须**两个都给**。
  只给 `npmDeps = null` 会回退到默认 `npmConfigHook`（它先要求 `$npmDeps` 非空、
  再 `diff` src 与缓存里的 `package-lock.json`），而没有 lockfile 的上游必然构建失败；
  给一个无 setup-hook 的空目录派生才等于跳过整个 hook。
- `dontNpmBuild = true;` —— 上游没有 build script。
- **不要用默认 `npmInstallHook`**：它在 packlist 拷贝后无条件 `find/cp -r node_modules`，
  零依赖树没有 `node_modules` 会失败（`dontNpmPrune` 只跳过 prune 那一步）。
  本包自定义 `installPhase`，按上游 `files` 白名单逐个 `cp`（`locale/`、`scripts/`、
  `docs/` 整目录拷，避免 `locale/*.json` 这类 glob 在非 structuredAttrs 下的分词问题）。
- 产物必须保留 `package.json`（resolver 用它读 `dsh.bundle.patch` 并校验
  `name == $out/lib/node_modules/dsh-headless-display`）与 `cordis.patch.yml`。

## 必须打的补丁：查看器默认值

nixpkgs 的 `gtk-vnc` 只装 `gvnccapture`，**没有** `gvncviewer`（GTK 查看器被裁掉），
所以上游默认的 `viewer: config.viewerPath || 'gvncviewer'` 在 NixOS 上永远解析不到，
`iso_display_popout` 会直接报「缺少 VNC 查看器」。`postPatch` 把默认值改成
`vncviewer`（TigerVNC）；插件本来就按 basename 区分查看器，`vncviewer` 会走
`localhost::<port>` + `-Shared` 的正确参数路径。`runtimeDeps` 里因此放 `tigervnc`。

## 第二个补丁：doctor 返回 undefined 让工具结果校验直接失败

`iso_display_doctor` 在 NixOS 上**永远**报 `tool "iso_display_doctor" returned
invalid output: value is not lossless JSON`，而同一个 `doctor()` 走 HTTP
`/gui-isolation/doctor` 却返回 200 和完整 JSON——两条路径的分歧就在 `undefined`：

- `JSON.stringify` 会**静默丢弃**值为 `undefined` 的键，HTTP 出去看着正常；
  实测 135 个键在序列化后只剩 123 个。
- dsh 校验的是**内存里的值**，`undefined` 不是 JSON 值，整条工具调用作废。

来源有三处（都在 `doctor()` 里）：

1. `package: (PACKAGES[distro.family]?.map || {})[name] || undefined` ——
   `PACKAGES` 只覆盖 debian/fedora/arch/suse/alpine，NixOS 命中 `family: 'unknown'`，
   十二个依赖条目全部落到 `undefined`（这是每台 NixOS 上必现的那一半）。
2. `package: (...).identify` / `package: (...).gvncviewer` —— 同样的原因，无 `|| null` 兜底。
3. `backends.sway.gpu: ... : undefined` —— 后端不是 sway 时（如 `backend: 'xvfb'`）。

`patches/0001-doctor-return-null-instead-of-undefined.patch` 把这四处改成 `null`。
不要顺手把 `deps[].path` 也改成 `|| null`：`which()` 找不到时返回的就是 `null`
（不是 `undefined`），改它属于噪音。

验证手法（不依赖 dsh 运行）：用假 `ctx` 直接调插件注册的 `execute`，再按
「遍历找 `undefined` + `JSON.parse(JSON.stringify(x))` 前后键数是否相等」判定
lossless。复现与修复都是这一个脚本，旧包 12 处 `undefined` / 135→123 键，
新包 0 处 / 135→135。

上游应修的版本更彻底：`doctor()` 输出干脆不带这些键（像 `listDisplays()` 里
`if (v !== undefined) item[k] = v` 那样），或声明 schema 允许 `null`。

## runtimeDeps：插件只认 PATH

`which()` 只沿 `process.env.PATH` 解析命令（裸命令名不能 `existsSync`），
dsh 把 `passthru.runtimeDeps` 里的每个包 `--prefix PATH` 注入 launcher，
所以**所有后端二进制都必须列在 `runtimeDeps`**，否则 `iso_display_doctor` 报缺、
`requireBins()` 直接抛错：

- 后端/抓屏：`xvfb`、`sway`、`xwayland`、`grim`
- X 工具：`xdotool`、`xdpyinfo`、`xwininfo`、`imagemagick`（`import`/`identify`）
- 弹窗：`x11vnc`、`wayvnc`、`tigervnc`（`vncviewer`）
- 进程与音频：`procps`（`pgrep`/`ps`）、`pulseaudio`（`pactl`，在 PipeWire 上作为客户端照常可用）、`bash`（VNC 端口探测用 `/dev/tcp`）

注意 nixpkgs 已弃用 `xorg.xdpyinfo` / `xorg.xwininfo`，用顶层 `xdpyinfo` / `xwininfo`。

## 部署侧的已知事实（不是打包能修的）

- **九条 `/gui-isolation/*` 路由不受 dsh 内核 `/api` 的鉴权围栏保护**：无 cookie、
  无 `Host`/`Origin`/`Sec-Fetch-Site` 校验。回环绑定下仍可被任意网页 CSRF
  （简单 POST 无预检）与 DNS rebinding 读取。安全审计 SEC-1 有实测。
  → 不要在 LAN profile 上开这个 bundle；QQ 群面也不要开放这些工具。
- **`iso_display_run` 是未沙箱的任意命令执行**，子进程继承宿主全部 env
  （含 `SSH_AUTH_SOCK`、会话 D-Bus、真实 `XAUTHORITY`），dsh 的只读权限预设
  不约束第三方工具。→ 本仓库只把它放进 `extraBundles`（web/tui 全量 profile），
  **刻意不加入 `qq-agent-presets` 的 allow list**（群聊面保持隐藏）。
- `iso_display_stop` 无条件信任 `$stateDir/<n>.json` 的 `pid` / `runDir` /
  `audioModule`（任意 pgid kill、任意 `rm -rf`）。stateDir 必须留在 0700 的 home 内，
  共享/可写目录（`/tmp`、NFS）会把这个能力交给同 uid 任意进程。
- sway 后端要 `WLR_BACKENDS=headless` + 能打开 `/dev/dri/renderD*`：用户需在
  `render` 组（本机 `idols-ai` 已满足）。没有 sway 时 `backend: auto` 退 Xvfb
  （无 DRI3，Vulkan 只能 llvmpipe）。
- `stateDir` 默认 `~/.dsh-headless-display`；impermanence 主机要把它列入持久化，
  否则重启后 `displayAuth`/`displayWayland` 映射丢失（display 进程本身也随重启消失，
  影响仅限于旧状态文件残留）。
