# cua-driver 打包笔记

上游：<https://github.com/trycua/cua>（MIT），Rust 实现的 computer-use driver
（MCP server + CLI）。锁定 tag `cua-driver-rs-v0.38.0`
（commit `85e2b1318bd77ccf3cfa88ccdf875a4bb7eaed19`），
`nix-update --flake --version-regex '^cua-driver-rs-v(.*)$'` 随 tag 更新。

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

## 与 nur-ryan4yin 版的关系

nix-config 原先从 `nur-ryan4yin` 取预编译二进制包（0.36.0，只有 portal-input）。
本包取代之：版本更新、Wayland portal 捕获、skill pack 三件事都需要自建。

## 验证

```
nix build .#cua-driver
./result/bin/cua-driver --version
./result/bin/cua-driver manifest | head   # CLI 面自描述
```
