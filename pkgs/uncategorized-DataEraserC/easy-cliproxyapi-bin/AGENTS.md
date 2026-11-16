# easy-cliproxyapi-bin（GUI 二进制落在只读 store 的处理）

- **GUI 二进制在只读 store 里：既会被 `wrapGAppsHook3` 包装，也会被应用当作可写数据目录**：`wrapGAppsHook3` 会包装 `$out` 下所有**可执行**文件（含 `libexec/`），把真实二进制改名 `.X-wrapped` 并在原位放一个 exec store 路径的 wrapper——此时启动脚本再 `cp` 它，`current_exe()` 仍落在只读 store。修复分两步：
  - 真实二进制用 **0644**（去掉可执行位）装进 `$out/libexec/<pkg>/`，hook 的 `find -executable` 会跳过它（`autoPatchelfHook` 仍按 ELF magic 正常修补）
  - `$out/bin/<main>` 写成启动脚本，每次启动把二进制与随附资源 `install -C`（coreutils，仅内容变化时复制）到 `${XDG_DATA_HOME:-$HOME/.local/share}/<pkg>` 再 `exec` 副本；同时**不要**安装上游的便携版清单（如 `portable-app.json`），让应用内置自更新保持禁用

- **上游「先发布 release 条目、后上传资产」会让 `nix-update` 把版本写前进却拿不到哈希**（2026-11-16 实例，run 43831186863）：`v0.3.108` 的 release 在 08:22:24Z 就已出现在 `releases.atom`，而 `EasyCLIProxyAPI-v0.3.108-Linux-amd64.tar.gz` 到 08:36:29Z 才上传完；auto-update 在 08:34:58Z 读到 feed，随即 prefetch 得到 `curl: (22) ... 404`（nix-update 自己的 4 次重试加起来只有约 7 秒），于是 `version` 已改成 0.3.108、hash 仍是 0.3.107 的，然后抛 `UpdateError: failed to retrieve hash ... easy-cliproxyapi-bin.src`。CI 的 auto-update **无论更新脚本退出码如何都会提交工作树**（`dataeraserc-auto-update.yml` 只有 placeholder-hash 一道闸），所以这种「半更新」直接上了 main，包在主分支上不可构建。修法有两条要点：
  - `nix-update-script { }` 对这种包不安全，改成自定义 `update.sh`（`passthru.updateScript = [ (toString ./update.sh) ];`）：先 `curl -fsSI` 轮询**资产本身**是否可下载（6 次 × 60 s，覆盖实测 14 分钟缺口），确认可下载后才 `nix store prefetch-file --json` 取哈希，最后才 `sed` 写 version + hash，并 `nix build .#<pkg>` 收尾。顺序必须是「先确认可下载 → 再算哈希 → 最后落盘」，任何一步失败都不能留下半更新的文件。
  - 反例参考 `cua-cli/update.sh`：它的 prefetch 重试只有 4 次共约 90 秒，够对付「tag 先行、资产随后」，但不够覆盖十几分钟的缺口；这类 release 的等待预算要按实测缺口给，且必须自己跑 `nix build` 验证（`nix-update` 的 prefetch 失败时**不会**回滚它已写入的 `version`）。
