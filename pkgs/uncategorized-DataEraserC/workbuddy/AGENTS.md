# workbuddy 打包经验

- **国际站 Linux 下载已失效，走国内站**：`https://www.workbuddy.ai/v2/update?platform=workbuddy-linux-x64-deb` 返回的 5.5.2 URL 已 404；`https://www.workbuddy.cn/v2/update?platform=workbuddy-linux-{x64,arm64}-deb` 返回可用的 5.6.2 `.deb` 且带 `sha256hash`。两个平台 URL 都带构建哈希后缀（如 `-c7b525f3.deb`），无法从版本号推出，因此用 `release.json` 保存完整 URL；版本变化时用接口返回值重写。
- **`dpkg -x` 解包即可**：deb 只有一个顶层 `/opt/WorkBuddy`（Electron 本体 + 内置 CLI + Python runtime，安装体积约 1.6GB），另有 `usr/share/{applications,icons}`。用 `dpkg` 作 nativeBuildInput，不要走 `ar` + `tar` 手撕。
- **koffi 的跨平台预编译会毒化 autoPatchelf**：`resources/app.asar.unpacked/node_modules/koffi/build/koffi/` 下带了 linux/darwin/win32/freebsd/openbsd/musl 全套绑定，其中 openbsd 变体是 x86_64 ELF 且依赖 `libc++.so.9.0`/`libpthread.so.26.1` 等，autoPatchelf 会按架构放行后报缺依赖。installPhase 里按目标架构只保留 `linux_x64`/`linux_arm64` 子目录（`find ... ! -name "$koffiArch" -exec rm -rf {} +`），musl 变体随之删除；`libc.musl-*.so.*` 的 ignore 仍保留兜底。
- **chrome-sandbox 在 store 里无法 setuid**：wrapper 必须加 `--no-sandbox`，否则 Electron 起不来（SUID helper 权限错误）。Wayland 按仓库 qq 的 ozone 自适应写法透传 `NIXOS_OZONE_WL`/`WAYLAND_DISPLAY`。
- **不需要 versionCheckHook**：这是 GUI 应用，`--version` 会直接进入主进程而不是打印版本；用构建成功 + 实跑主进程验证。实测 `result/bin/workbuddy --version` 能走到 Electron main、加载内置 CLI/Python，只有沙箱里 `/home/...` 不可写导致的正常 ENOENT 噪音。
