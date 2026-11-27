# qoder-cn-wayland

`qoder-cn` 的 Wayland/waypipe 变体。基础包保持原样，本包只通过 `overrideAttrs` 在 `postInstall` 里重打包 `resources/app.asar`，不复制整棵树，也不改上游文件。

## 为什么需要

- 主窗口用 `show:false` 创建，上游唯一的 `show()` 在 `ready-to-show` 回调里（0.5.20 的 `out/main/electronMain.js`，`m.once("ready-to-show",()=>{...nI?.placeForInitialShow(m),m.show()...})`）。
- Wayland/waypipe 下未 map 的窗口不产首帧，`ready-to-show` 可能永远不触发，于是窗口永远不显示，看起来像卡死。
- 修法是在回调注册前挂 1.5 秒兜底：
  ```js
  setTimeout(()=>{m.isDestroyed()||m.isVisible()||(nI?.placeForInitialShow(m),m.show())},1500),
  ```
  正常路径下 `ready-to-show` 先到，定时器发现已可见就空转；waypipe 下由它负责 `show()`。

## 版本耦合

- 0.5.20 锚点是 `m.once("ready-to-show",()=>{const z=Date.now();`，show 变量是 `nI`。
- 0.5.18 是 `const q=Date.now()` + `wA`；不要把 0.5.18 的补丁直接套到 0.5.20。
- `repack-asar.py` 在锚点计数不为 1 时硬失败；如果未来上游自带兜底（出现 `InitialRevealGate` 或 `ready-to-show-timeout`），脚本会原样放行并打印提示，此时应核对上游实现后删除本包或改为只做检测。
- 国际版 `qoder` 0.5.20 的 `out/main/electronMain.js` 锚点和变量名与 CN 版相同；若要给国际版也提供变体，复用同一脚本、把 `appDir` 换成 `Qoder` 即可。

## asar 重打包规则

- `size` 必须是 JSON 整数，`offset` 必须是十进制字符串；写成字符串会让 Electron 读不到条目（`Cannot find module .../app.asar/...`），但字节和哈希看起来都正常。
- 替换文件后要重算该条目的 `integrity`（SHA256 + blockSize 4194304 + blocks），并按原物理顺序重算所有条目的 `offset`。
- 未修改的条目必须逐字节保持不变；构建后用脚本对比，确认只有 `out/main/electronMain.js` 不同。
- 不要解包成 `resources/app/` 目录模式：`app.isPackaged` 会变成 `false`，asar 里有大量分支依赖它。

## 用户侧用法

- waypipe 必须加 `-n`/`--no-gpu`，否则 Chromium 在 GPU/DMABUF 通道上可能先卡住，和本补丁是两回事。
- 需要让 wrapper 注入 ozone 参数：`NIXOS_OZONE_WL=1 waypipe -n ... qoder-cn`，或直接 `qoder-cn --ozone-platform=wayland`。
- `Missing X server or $DISPLAY` 是没走 Wayland 的预期报错；`mimeapps.list ... Read-only file system` 是 home-manager 符号链接噪音，均不是卡死原因。

## 验证

```bash
nix build .#qoder-cn-wayland
# 检查输出里的 asar：只有 out/main/electronMain.js 不同，且含 1.5s 兜底
```
