# cua-driver 打包笔记

上游：<https://github.com/trycua/cua>（MIT），Rust 实现的 computer-use driver
（MCP server + CLI）。锁定 tag `cua-driver-rs-v0.52.4`
（commit `5ee5974492839bb3b5a3db8919e3cf517e23ffe3`），
`update.sh` 随 tag 更新（自定义脚本，机制见下）。

## 源码构建而非预编译二进制

上游自带 Nix 配方（`nix/cua-driver/package.nix`），本包沿用它：

- **src 取整个仓库**：cua-driver crate 按 path 依赖
  `libs/cua/crates/cua-telemetry`，工作区在 `libs/cua-driver/rust`，
  `postUnpack` 把 sourceRoot 指到那里，`-p cua-driver` 只编 Linux 依赖图
  （platform-macos / platform-windows 等成员被 cfg 挡掉）。
- **`cargoLock.lockFile` 指向提交在仓库里的 Cargo.lock**（importCargoLock），
  没有需要手维护的 cargoHash；全是 crates.io 依赖、零 git 依赖。
- **两个 portal feature 都开**（`portal-input,portal-capture`，与上游配方一致）：
  portal-input 是 libei RemoteDesktop 输入，portal-capture 是 PipeWire
  ScreenCast 捕获——wlroots 合成器（niri/sway）两者都需要。官方 release 二进制
  只带 portal-input，这是自建的理由之一。
- 构建期需要 `rustPlatform.bindgenHook`（libpipewire/libspa 的 SPA pod codegen
  要 libclang）；运行期链 libX11/libXi/libXtst/libXext、libei、libxkbcommon、pipewire。
- **新增依赖 crate 里只要有一个走 pkg-config 找系统库，缺的就是 `buildInputs` 而不是 Rust 依赖**：
  0.52.x 的 `cursor-overlay` 加了 `zstd`，nixpkgs 的 `cargo-setup-hook.sh` 会无条件
  `export ZSTD_SYS_USE_PKG_CONFIG="1"`，于是 `zstd-sys` 的 build.rs 走 `pkg-config --static
  --libs --cflags libzstd`，找不到就 panic：`Can't probe for zstd in pkg-config: ... No package
  'libzstd' found` / `The system library 'libzstd' required by crate 'zstd-sys' was not found`
  （builder exit 101）。修法就是在 `buildInputs` 加 `zstd`（pkg-config 由 hook 注入的
  `PKG_CONFIG_PATH` 找到 `libzstd.pc`）。注意 `--static` 并不会要求 `.a`：`pkg-config` crate
  的 `is_static_available()` 找不到静态库时会退回 `rustc-link-lib=zstd` 动态链接，产物
  `NEEDED libzstd.so.1` + RUNPATH 指向 nixpkgs zstd 的 `out`，无需 `zstd.static`。
  排查手法：`nix log <drv>` 看 build.rs 的 panic，而不是猜 Cargo feature。
- `doCheck = false`：测试需要真实 X11 display 和 AT-SPI 总线。

## skill pack

同 release 的 `cua-driver-rs-v<version>-skills.tar.gz`（SKILL.md + 平台深挖文档）
装到 `$out/share/cua-driver-skills`，与二进制同版本。nix-config 侧把它软链到
`~/.dsh/skills/cua-driver`（dsh 的 user 级 skill 根）。driver 自带的
`cua-driver skills install` 会联网抓 GitHub release 资产并写进各 agent 目录，
Nix 下不用它。

## 更新机制（update.sh）

nix-update 驱动不了这个包：①releases atom feed 只列最近约 10 条，被
`nightly-cua-driver-rs-*` / `cua-spaces-*` / `nightly-lume-*` 占满，
`--version-regex` 永远匹配不到，直接抛 `VersionError` 让整个 CI 挂；
②版本在 `versionData.tag` 里派生，文件里没有 `version = "..."` 字面量，
nix-update 无法重写 tag，src/skills 哈希也无从更新。所以 update.sh 自己来：
`git ls-remote --tags` 过滤 `cua-driver-rs-v<semver>`（行尾锚定，自动排除
`nightly-*` 与 `^{}` peeled ref）→ **从新到旧取第一个 skills 资产真实存在的
tag**（`curl -fsIL` 打 `releases/download/<tag>/<tag>-skills.tar.gz`，200/404
且不耗 API 配额）→ 与 default.nix 里的 tag 比较，相同就
`exit 0` → 否则先算好两个新哈希再一次性 sed tag + 2 处哈希，最后
`nix build .#cua-driver` 验证。

**tag ≠ release**：release-please 开 PR 的瞬间就推 git tag，GitHub release
（连带 `-skills.tar.gz` 资产）可以滞后甚至发布失败——2026-11-21
`cua-driver-rs-v0.56.5` 裸 tag 挂在仓库里而最新已发布 release 是 v0.56.4。
裸 tag 做 `fetchFromGitHub` 的 src 毫无问题（tag 存在即可），但 skills 的
fetchurl 会 404，「取最新 tag」的写法在 tag 早于 release 的窗口里每 run 必挂。
所以选 tag 必须以**资产存在性**为准，不能只看 `ls-remote` 的最大值；也不要用
release 的 pre-release 标志过滤——上游每个 driver release 都是 pre-release
（0.55.0 亦然），按它过滤会永远停更。

**哈希必须用 FOD-echo 算，不能用 `nix store prefetch-file`**：GitHub 的
`archive/refs/tags/*.tar.gz` 是按需生成的归档，宿主机 prefetch 下载到的
字节流与构建沙箱里 fetchurl 下载到的不是同一个变体（2026-10-27 对本 tag
实测：prefetch `sha256-w8pz...` vs 构建 `sha256-Fpryc...`，且各自稳定
复现），prefetch 出来的哈希过不了 FOD 校验。做法与 nix-update 内部同款
（见根 AGENTS.md「tarball prefetch 哈希」一节）：以 dummy 哈希构建同一个
fetchFromGitHub / fetchurl，从报错的 `got:` 行取真实哈希。skills 那个是
release asset（字节稳定），但统一走 FOD-echo，只保留一种机制。

tag 未变时脚本仍会 `nix build .#cua-driver.src` 自检：哈希没坏是 store hit
（不下载）；被上游就地重生成归档坏了（同 commit、新字节），就从 `got:` 行
取新哈希自愈，再全量构建验证。

**改写必须在失败时回滚**：`update.sh` 的结构是「先算哈希 → 再 sed 改写 → 最后
`nix build` 验证」，而末尾这次构建是**唯一**能拒绝坏版本的关口；一旦它失败，文件
已经处在「新 tag + 新哈希」的状态。CI 的 auto-update **无论更新脚本退出码如何都会
提交工作树**（`dataeraserc-auto-update.yml` 只有 placeholder-hash 一道闸），所以
「构建失败的版本」会被直接提交（2026-11-16 `cua-driver-rs-v0.52.4` 实例：缺 libzstd
导致 builder exit 101，但 tag/hash 已改写并被 `25965b64` 提交，main 上的 cua-driver
从此不可构建）。修法：脚本开头 `cp "$DEFAULT_NIX" "$BACKUP_NIX"` 并
`trap revert_on_exit EXIT`，非零退出时把文件恢复回去，这样「更新失败」的结果是
**仍然可构建的旧版本**。唯一例外是 tag 未变分支里的 src 哈希自愈
（`update.sh` 的 102–111 行）：那里的旧哈希已被 fetcher 证明是错的，恢复它只会
让包保持不可获取，所以先 `trap - EXIT` 再刷新哈希。

## 与 nur-ryan4yin 版的关系

nix-config 原先从 `nur-ryan4yin` 取预编译二进制包（0.36.0，只有 portal-input）。
本包取代之：版本更新、Wayland portal 捕获、skill pack 三件事都需要自建。

## 验证

```
nix build .#cua-driver
./result/bin/cua-driver --version
./result/bin/cua-driver manifest | head   # CLI 面自描述
```
