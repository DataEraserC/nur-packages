# qwenwork

千问办公 QwenWork（<https://qwenwork.cn>，阿里巴巴 Qoder 团队的桌面级 AI 办公助手，Electron 38，闭源）。只以 `.deb` 分发，x86_64 与 aarch64 各一个包；官方无 Linux AppImage/tar 包，`/download` 的企业版链接指向 VPC 专有版本，本包只跟公有云 `assets.qwenwork.cn` 的两个对象。

## 产物来源：固定 `latest` 对象键，版本必须从 deb 自身读

- 下载 URL 是**固定对象键**：`https://assets.qwenwork.cn/release/latest/qwenworkcn-linux-{amd64,arm64}.deb`（阿里云 OSS `qwenwork-assets.oss-cn-shanghai.aliyuncs.com`）。与 mobileclaw 不同，这里**没有** 302 管理器端点，直接 GET 即 200，HEAD 也开放，`fetchurl` 直 pin 即可。
- **版本号只能从 deb 的 control 字段读**（`dpkg-deb -f <deb> Version`，如 `2.0.2-26111601`），原因有二：
  1. URL 里只有 `latest`，无版本化路径（`release/2.3.2/...` 实测 404，别再试）；
  2. **官网 release notes 与 OSS 对象是两套会漂移的事实**：2026-11-28 时 <https://docs.qwenwork.cn/release-notes/desktop> 列到 2.3.2（2026-11-27），而 `latest` 对象仍是 2.0.2-26111601（last-modified 2026-11-16）。照抄文档版本等于把 2.3.2 的版本号配上 2.0.2 的字节。
- `update.sh` 用 **OSS ETag** 做零下载的变更探测：HEAD 两次架构的 ETag，都与 `release.json` 里记录的一致 → `already at` 直接退出；任一变化 → 两个 deb 全量下载、读 control Version（两个架构不一致即硬失败）、写回 version/hash/etag，然后真实 `nix build` 验证。OSS 对象是原地重传（ETag 形如 `"9F83...-153"`，multipart 分片标记），**没有 ETag 探测就绕不开每次全量下载 800MB**。
- `version` 字段保留 deb 的完整字符串（含 `-26111601` 构建号后缀）：上游会用同一语义版本重传新构建号，只比 `X.Y.Z` 会漏掉这种更新。
- electron-updater 的 feed（`resources/app-update.yml` → `https://static.qoder.com.cn/qwen-work-cn/releases`）整体 403（bucket ACL），`latest-linux.yml`/`manifest.json` 全不可用，不要试图从那里取版本。
- 与 qoder-cli CN（`static.qoder.com.cn/qoder-cli-cn`）同属 Qoder 系基建：应用包内 `resources/bin/qoderclicn` 就是 Qoder CN CLI 本体。

## 打包要点

- 标准 Electron deb 布局，但**多一层 `apps` 目录**：`/opt/apps/QwenWorkCN/{qwen-work-cn,resources/...}`，`usr/share/applications/qwen-work-cn.desktop`（`Name=千问办公`、`Icon=qwen-work-cn`、`StartupWMClass=qwenworkcn`、`MimeType=x-scheme-handler/qwenwork-cn`），hicolor 图标 16–512 齐全（无 1024x1024 缺档问题，见 _docs/AGENTS.md「桌面图标」）。本包把 `opt/apps/QwenWorkCN` 原样拷到 `$out/opt/QwenWorkCN`，Exec 重写为 `$out/bin/qwenwork`。
- 包名/pname 用 `qwenwork`（站点品牌）；上游 deb 包名与二进制名是 `qwen-work-cn`，desktop 文件的 Icon/WMClass 保留上游名，因此 launcher 图标与窗口识别不受改名影响。
- **`dontStrip = true` 是全树性的**：`resources/bin/` 下有 Bun 单文件可执行（`qoderclicn` 179MB、`qwenwork`/`qwenwork-linux-x64` 各 19MB，JS payload 在 ELF 段之外），strip 会把它退化成裸 Bun CLI（fork 规则同 codebuddy/codearts）。1.4G 的树里无法保证只对 Electron 三件套关 strip，统一关掉。
- 无 musl 预编译、无内置 Python（mobileclaw 1.9.9 的 `libxcrypt-legacy` 问题不存在）；依赖清单照 mobileclaw 的 Electron/GTK 栈，deb 自身 Depends 声明 gtk3/nss/libsecret/atspi/libuuid 等，与 buildInputs 是同一套。
- `--no-sandbox` + `NIXOS_OZONE_WL` ozone 自适应，`makeShellWrapper` 而非 `makeWrapper`（wrapGAppsHook3 的 make-binary-wrapper 会在构建期烙死 `${NIXOS_OZONE_WL:+...}`，mobileclaw AGENTS 有完整说明）。apparmor-profile 是上游给 deb 路径的 unconfined 放行，NixOS 不装 AppArmor，无需处理。

## 状态路径（决定 nix-config multi-instance 的 paths）

Electron `package.json` 无 `productName`（`name = "qwen-work-cn"`），但应用自己 `app.setPath('userData', ...)` 到 **`~/.config/QwenWorkCN`**（主进程日志 `[App] userData path: ...` 直接可证）。xvfb 实跑 2.0.2 首启 40 秒内落盘（scratch HOME 实测）：

- `~/.qwenworkcn/` —— 应用自己的状态根：`machine-id`、`app-data/`（host-content.db）、`bin/ext/`（启动时从 `resources/bin/` 释放的 builtin bins，日志 `[BuiltinBins] Builtin bin released`）、`cache/`、`skills/`、`host-agent-responses.db`、`mcp-adaptor.config`。**这一层遵循 `$HOME`**（HOME=scratch 时落在 scratch 下）。
- `~/.config/QwenWorkCN/` —— Electron userData（Cache、Local Storage、`agents.db`、`relay-port.json` 等），**单实例锁 `SingletonLock`/`SingletonSocket`/`SingletonCookie` 在这里**。实测该路径由 `app.setPath` 硬编码解析，**不跟 `$HOME`**（HOME=scratch 时 userData 仍落在 passwd 的真实家目录）——multi-instance 的 bind mount 覆盖的是真实路径，所以两种解析方式都被覆盖，不影响隔离。
- `~/.config/{google-chrome,microsoft-edge}/NativeMessagingHosts/` —— 浏览器连接器 manifest（`native-messaging-host.sh`），multi-instance 不重定向（共享浏览器配置，与 xiaohuanxiong 对浏览器集成的处理一致）。
- `~/.pki/nssdb` —— Chromium 标准 NSS 库，随用随建，不入 preservation。

未观测到 `~/QwenWork` 一类的默认工作区目录（未登录、未跑 agent 的首启不建；工作区路径要登录后才能确认，multi-instance 的 paths 先按上面两处配，工作区若实际出现再补）。

`userDataDir` 必须设 `.config/QwenWorkCN`（Electron 锁名由该路径派生）。

## 验收

无 `--version`（Electron 主程序会把参数交给应用）。冒烟：`HOME=<scratch> xvfb-run -a $out/bin/qwenwork`，约 23 秒后日志出现 `ready-to-show`/`Window ready to show`、scratch HOME 下出现 `.qwenworkcn/` 即正常（无头环境停在登录页是预期；反复出现的 `AxiosError: timeout of 10000ms exceeded` 是无网络环境下的探测请求失败，不是缺陷）。二次启动（在已有状态上）实测存活、`[NativeMessaging] Native messaging host registered` 成功；`[ExtensionRelay] Chrome extension deployment failed ... EACCES`（stage=metadata，rollback 也失败）是可恢复 WARN——随后 NativeMessaging 注册与 Browser Relay worker 照常启动，不是 Nix 打包引入的启动障碍。释放到 `~/.qwenworkcn/bin/ext/` 的文件模式**混杂**：应用自己写的顶层文件是 0644/0755，但 `ext/openyida/<hash>/` 里的 node_modules 整树保留了 store 的 0444/0555（`fs.cp` 保留源模式）——该树按内容哈希目录存放、实测二次启动不重写，对应用无害，但会在家目录留下删不掉（需先 `chmod -R u+w`）的只读残留；若未来版本改成原位重写（xiaohuanxiong 的 staging 模式），就得给启动器加可写副本 + ro-bind。不需要现在做。构建期验证：`nix build` 通过 + `ldd` 零 `not found`。

**autoPatchelf 唯一的额外依赖是 `libXt`**（`uiohook-napi.node` 全局键鼠钩子要 `libXt.so.6`），其余全部在 mobileclaw 同款 Electron/GTK 依赖清单内。注意 `libxt` 要同时进**形参列表和 `libraries` 列表**——只进形参不改 `buildInputs`，drv 哈希不变、auto-patchelf 照样失败（2026-11-28 实例：改了形参漏了列表，三次构建同一个 drv 反复报同一个缺依赖，排查时间全浪费在怀疑 Nix 脏树缓存上）。
