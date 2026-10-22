# cua-cli 打包笔记

上游：<https://github.com/trycua/cua>（MIT）。锁定 tag `cua-sdk-v0.7.0`，
`nix-update --flake --version-regex '^cua-sdk-v(.*)$'` 随 tag 更新
（同 tag 发 cua-driver-rs-v* / cua-sdk-v* 两套，regex 只认 sdk 这条线）。

## 预编译二进制 + autoPatchelf，不源码构建

- release asset `cua-cli-<version>-linux-x64.tar.gz` 只有一个裸 `cua` 文件
  （155MB，strip 后约 100MB——上游没 strip，fixup 默认会剥）。
- 动态链接但 NEEDED 只有 glibc + libgcc_s，最高符号 GLIBC_2.30，
  `autoPatchelfHook` + `stdenv.cc.cc.lib` 就是在 NixOS 上跑起来的全部代价。
  不满足于「能跑」的验证放 `doInstallCheck`（fixup 已换解释器之后），
  postInstall 里跑会撞上沙箱没有 /lib64/ld-linux 的问题。
- 平台只声明 `x86_64-linux`：arm64 有对应 asset，需要时再加分支。

## skills 不在 release 里

CLI release 不带 skills（cua-driver 的 release 带，`cua` 的不带），
从同 tag 的源码树逐文件 `fetchurl`：`libs/cua/skills/{cua-sandboxes,
gui-automation}` 共 3 个文件，装到 `$out/share/cua-skills`。
版本对齐是按 tag 取的——skills 描述的是 CLI 自己的命令面。

## 这个包是干什么的

`cua mcp`（stdio MCP server）暴露沙盒面：`sandbox_*` 生命周期 +
`computer_*` 桌面控制（每次调用用 `sandbox` 参数选目标），驱动的是
cua-vmm 管的容器「电脑」（Podman/Docker + gVisor/runc、QEMU、Lume），
**不是本机会话**——本机桌面是 cua-driver 那条线（见 cua-driver 包）。
实测（无 podman 环境）：initialize + tools/list 正常返回 138 个工具，
server 启动不依赖容器引擎。

dsh 侧集成见 dsh-cua-sandbox 包；skills 由 nix-config 的 dsh 模块软链到
`~/.dsh/skills/`（dsh 不在 CLI 自带 `cua skills install` 的 agent 列表里）。
