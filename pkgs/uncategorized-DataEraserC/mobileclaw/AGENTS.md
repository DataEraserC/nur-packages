# mobileclaw

移动云 MobileClaw（中国移动的桌面级 AI 办公智能体，Electron，闭源）。只以 `.deb` 分发，x86_64 与 aarch64 各一个包。

## 产物来源：必须走「管理器端点」，不能直接 pin 对象存储 URL

产品页 <https://ecloud.10086.cn/portal/product/hotCase> 的五个下载按钮是 JS 渲染的 `<div class="ecloud-button" data-url="...">`，**不是 `<a href>`**：

| 按钮 | data-url 的 `os=` 参数 |
| --- | --- |
| Windows | `windowsClient` |
| Mac (intel) | `macIntelClient` |
| Mac(M) | `macAppleClient` |
| Linux(x64) | `linuxX64Client` |
| Linux(ARM) | **`linuxArm64Client`**（不是 `linuxARMClient`，写错返回 400） |

端点 `https://zhenze-huhehaote.cmecloud.cn/desktop/manager/public/link/download?os=<上面>` 返回 **302**，指向 `https://eos-huhehaote-1.cmecloud.cn/maas.ecbot/<os>/<版本>/MobileClaw_<版本>_<arch>.deb` 加一整套 SigV4 查询串（`X-Amz-Expires=1800`）。

**直连对象存储（去掉签名）恒 403**，所以不要把解析出的带签名 URL 写进 `release.json`——30 分钟后失效。正确做法是 pin **管理器端点本身**：`fetchurl` 会跟随 302，`hash` 仍然钉住字节。`name = source.file` 让 store 路径可读（否则会叫 `download?os=linuxX64Client`）。实测 `builtins.fetchurl` 走同一路径也能校验通过。

**版本号以解析出的 `.deb` 文件名为准**（`sed -nE 's#.*/MobileClaw_([0-9][0-9.]*)_[a-z0-9_]+\.deb$#\1#p'`），不要让 `release.json` 里的 `version` 与文件名成为两份会漂移的事实。`update.sh` 就是按这个口径写的。

**版本捕获组必须是 `[0-9][0-9.]*`，不能是 `[^/]*`**：文件名是 `MobileClaw_<版本>_x86_64.deb`，arch 里的下划线让 `[^/]*` 能回溯出更长的合法匹配——`1.9.8_x86`（剩下的 `_64` 恰好接上 `_` 分隔符 + `[a-z0-9_]+` + `.deb`），于是「无更新」的运行也会得到 `new_version=1.9.8_x86 ≠ old`，白走一轮 prefetch（2026-11-21 CI 实例，mobileclaw 每 run 必挂）。数字加点匹配不到 `_`，天然免疫。

**prefetch 与 `release.json` 的 url 都要写管理器端点**：`update.sh` 曾把 302 解析出的裸对象 URL（剥掉 SigV4 签名）直接交给 `nix store prefetch-file`——裸 URL 现在无论 UA 一律 403（2026-11-21 实测），签名 URL 又 30 分钟过期不能 pin。端点链路（GET 跟随 302）实测任何 UA 都通，且与 `default.nix` 的 fetchurl 同一条链路，算出的哈希即构建所用。对象存储还拒绝 HEAD（403），只接受 GET，所以探测用 ranged GET（`-r 0-0`）而不是 `-I`。

**探测方法**：页面是 React SPA，`strings` 前端 bundle 找不到下载链接（里面 28 处 `.exe` 全是正则 `.exec`）。用 ego 浏览器打开后从按钮的 React props 里取：`el.getAttribute('data-url')`，或 `Object.keys(el).find(k=>k.startsWith('__reactProps$'))` 后读 `.props['data-url']`。

**注意**：不少中文二手文章（含 ai-bot.cn、搜狐、知乎转载）称「MobileClaw 只提供 Windows/macOS 双平台安装包」，**已过时**——当前页面明确有 Linux(x64) 与 Linux(ARM) 两个 `.deb`。

## 打包要点

- 标准 Electron deb 布局：`/opt/MobileClaw/{mobileclaw-desktop,resources/app.asar,resources/binaries/node-x86_64-unknown-linux-gnu}`，`usr/share/applications/mobileclaw-desktop.desktop`。desktop 文件里 `StartupWMClass=MobileClaw`、`Icon=mobileclaw-desktop`、`MimeType=x-scheme-handler/mobileclaw`。
- **`makeShellWrapper` 而不是 `makeWrapper`**：`wrapGAppsHook3` 会把 `make-binary-wrapper` 的 setup hook 带进链里，它把 `makeWrapper` 重定义为 `makeBinaryWrapper`；二进制版把 `--add-flags` 在**构建期**就编进 argv，`${NIXOS_OZONE_WL:+...}` 会原样（还被空格切碎）传给 Electron，任何环境都不生效。用 `makeShellWrapper` 后实测 `$out/bin/.mobileclaw-wrapped` 里保留了字面 `${NIXOS_OZONE_WL:+...}`，运行期才展开。验证方法：`grep -c NIXOS_OZONE_WL $out/bin/.mobileclaw-wrapped` 应为 1；`$out/bin/mobileclaw` 本身是 gapps 的 ELF 层，`strings` 找不到这个串是正常的。
- `autoPatchelfIgnoreMissingDeps = [ "libc.musl-*.so.*" ]`：它带的 `resources/binaries/node_modules/node-pty/prebuilds/` 只有 linux-x64，没有 musl 变体，但保留这条以防上游加回来。
- 依赖清单照 workbuddy（同一套 Electron/GTK 栈），实测 `ldd $out/opt/MobileClaw/mobileclaw-desktop` 零 `not found`。
- 无需 repack app.asar（上游没有 workbuddy 那种 `show:false` 在 Wayland 下不首帧的问题）。

## 状态路径（决定 multi-instance 的 paths）

真实启动一次后落在 `$HOME` 下三处，全部硬编码、无开关：

- `~/.config/com.cmss.mobileclaw-desktop/` —— `config.json`（deviceId、workspace、auth）、`run-state.json`
- `~/.config/MobileClaw/` —— Electron userData，**单实例锁 `SingletonLock`/`SingletonSocket`/`SingletonCookie` 在这里**
- `~/Documents/MobileClaw/` —— 默认 agent workspace（`config.json` 的 `workspace` 字段）

`~/.mobileclaw` 只是 asar 里的目录名过滤（`e.name.startsWith(".mobileclaw")`），不是状态目录，别加进 paths。

`userDataDir` 必须设成 `.config/MobileClaw`：Electron 的锁名由该路径派生，三个实例看到同一路径时第二个实例会把窗口交给第一个。

实测 multi-instance 隔离生效：实例目录下出现 `SingletonLock` 等三个文件，说明锁被 per-instance 重定向。

## 验收

没有 `--version`。冒烟方式：`xvfb-run -a $out/bin/mobileclaw`，看到 `[renderer] [bootstrap] N/8 ...` 逐级推进即正常（无头环境会停在登录页，这是预期的）。关掉时 `FATAL:electron_browser_main_parts.cc: Failed to shutdown` 是 timeout 强杀的副产品，不是缺陷。

`nix run --impure nixpkgs#xvfb-run -- -a $out/bin/mobileclaw --version` 这种写法在无 xvfb-run 的宿主上可用。
