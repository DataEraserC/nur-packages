# easy-cliproxyapi-bin（GUI 二进制落在只读 store 的处理）

- **GUI 二进制在只读 store 里：既会被 `wrapGAppsHook3` 包装，也会被应用当作可写数据目录**：`wrapGAppsHook3` 会包装 `$out` 下所有**可执行**文件（含 `libexec/`），把真实二进制改名 `.X-wrapped` 并在原位放一个 exec store 路径的 wrapper——此时启动脚本再 `cp` 它，`current_exe()` 仍落在只读 store。修复分两步：
  - 真实二进制用 **0644**（去掉可执行位）装进 `$out/libexec/<pkg>/`，hook 的 `find -executable` 会跳过它（`autoPatchelfHook` 仍按 ELF magic 正常修补）
  - `$out/bin/<main>` 写成启动脚本，每次启动把二进制与随附资源 `install -C`（coreutils，仅内容变化时复制）到 `${XDG_DATA_HOME:-$HOME/.local/share}/<pkg>` 再 `exec` 副本；同时**不要**安装上游的便携版清单（如 `portable-app.json`），让应用内置自更新保持禁用
