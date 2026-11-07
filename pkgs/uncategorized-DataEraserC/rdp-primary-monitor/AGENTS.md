# rdp-primary-monitor（GNOME Shell 扩展）

- **用途**：GNOME Desktop Sharing（RDP）以 `extend` 模式连接时，通过 Mutter `DisplayConfig` 的临时 `ApplyMonitorsConfig` 把 RDP 虚拟显示器设为主屏，并把普通应用窗口移到该显示器；断开时按原位置、尺寸和状态还原。只改临时显示配置，不写 `~/.config/monitors.xml`。
- **上游状态**：个人项目，未上架 extensions.gnome.org，作者声明由 AI 编写、无支持与路线图，`metadata.json` 只声明 GNOME Shell 49/50。源码钉在 HEAD `b537918949ee7ce6117845ade412ba2c9569a5b1`（2026-10-26，晚于 tag `v0.1.0`），版本记为 `0.1.0-unstable-2026-10-26`。
- **GNOME Shell 升级风险**：扩展依赖 Shell 内部 API（`Main.layoutManager`、`Meta.MonitorManager`、`DisplayConfig` 的临时配置语义、窗口跟踪信号等），Shell 50 → 51 一类升级可能使其加载失败、静默失效或抛异常。升级 GNOME Shell 后需重新验证，必要时更新本包的 `rev`/`hash`（上游可能不会同步适配）。
- **打包方式**：仓库此前没有 GNOME Shell 扩展包，因此按 nixpkgs `buildGnomeExtension` 的布局自建最小派生：只安装上游发布内容 `src/`（`extension.js`、`prefs.js`、`lib/`、`schemas/`、`metadata.json`）到 `$out/share/gnome-shell/extensions/<uuid>`，`uuid` 同时作为目录名并与 `metadata.json` 一致；用 `glib-compile-schemas --strict` 生成 `schemas/gschemas.compiled`。上游没有 `po/` 或 `locale/`，所以不处理翻译；若未来加入 `po/`，需用 `msgfmt` 生成 `locale/<lang>/LC_MESSAGES/<uuid>.mo`。
- **用户级临时启用（不改 nix-config、不 switch）**：先把产物目录复制到用户扩展目录，再在登录后启用：

  ```sh
  uuid=rdp-primary-monitor@michal-b-bozek.github.io
  ext=/nix/store/74ddpzmwwqvp027gxm55jygd51ycgn9c-rdp-primary-monitor-0.1.0-unstable-2026-10-26/share/gnome-shell/extensions/$uuid
  mkdir -p ~/.local/share/gnome-shell/extensions
  cp -r "$ext" ~/.local/share/gnome-shell/extensions/
  gnome-extensions enable "$uuid"
  ```

  Wayland 会话不会在运行中加载新扩展：复制后先注销再登录（`gnome-extensions enable` 在 Shell 尚未发现新扩展前可能报错，可在重新登录后再执行，或把 uuid 写进 `org.gnome.shell enabled-extensions`）。扩展不在 extensions.gnome.org，无法通过网页安装或自动更新；替代方式就是本包（或从上游 release 下载 `.shell-extension.zip` 后 `gnome-extensions install --force`）。
- **启用前提**：GNOME Shell 49/50 的 Wayland 会话，且 `gsettings set org.gnome.desktop.remote-desktop.rdp screen-share-mode extend`；扩展在 `user` 与 `unlock-dialog` 会话模式下运行。
- **停用**：`gnome-extensions disable rdp-primary-monitor@michal-b-bozek.github.io`；彻底移除时删除 `~/.local/share/gnome-shell/extensions/rdp-primary-monitor@michal-b-bozek.github.io`，再注销登录。
