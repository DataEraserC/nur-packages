# cua-driver 打包笔记

上游：<https://github.com/trycua/cua>（MIT），Rust 实现的 computer-use driver
（MCP server + CLI）。锁定 tag `cua-driver-rs-v0.38.0`
（commit `85e2b1318bd77ccf3cfa88ccdf875a4bb7eaed19`），
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
`nightly-*` 与 `^{}` peeled ref）→ 与 default.nix 里的 tag 比较，相同就
`exit 0` → 否则先算好两个新哈希再一次性 sed tag + 2 处哈希，最后
`nix build .#cua-driver` 验证。

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

## 与 nur-ryan4yin 版的关系

nix-config 原先从 `nur-ryan4yin` 取预编译二进制包（0.36.0，只有 portal-input）。
本包取代之：版本更新、Wayland portal 捕获、skill pack 三件事都需要自建。

## 验证

```
nix build .#cua-driver
./result/bin/cua-driver --version
./result/bin/cua-driver manifest | head   # CLI 面自描述
```
