# dsh-cua-driver 打包笔记

上游：<https://github.com/trycua/cua>（MIT）。本包是**自研 bundle**（上游没有对应的
dsh 插件仓库）：把 deepseek-ai/deepseek-harness 自带的实验性 Cua Driver MCP provider
挂进 dsh composition。版本号跟随 `cua-driver`（同仓库兄弟包），两者一起随
`cua-driver-rs-v*` tag 更新。

## provider 双包为什么要在 bundle 里

dsh kernel（`dsh-workspace` 的 nix-kernel 部署）只装 `apps/cli` 的依赖闭包，
`@deepseek-ai/dsh-computer-use` 与 `@deepseek-ai/dsh-experimental-computer-use-cua-driver-mcp`
不在闭包里（store 里 185 个 `@deepseek-ai/*` 没有它们），也没有 `dsh.bundle.patch`，
因此不是 runtime-bundle，`buildDshBundle.fromWorkspace` 拿不到。bundle 自己从 npm
tarball 装这两个预编译包，靠 `linkKernelNodeModules` 把 kernel 的 node_modules
链进每个包，让 peers（cordis / schemastery / dsh-mcp-client / dsh-brand）解析到
kernel 的唯一实例，而不是 npm 侧再拉一份重复实例。

- 两个 tarball 的 hash 钉死在 dsh `0.2.1-rc.2`；harness 升级时 default.nix 的
  assert 先报错（比 FOD hash mismatch 友好），再按新版重新钉。
- `command: cua-driver` 走 PATH 解析：`runtimeDeps = [ cua-driver ]` 由 dsh 启动器
 钉到 PATH，cordis.patch.yml 里不烤绝对路径。
- Linux 上 `cua-driver mcp` 自带 direct runtime（无 daemon socket），DISPLAY /
  WAYLAND_DISPLAY 从 dsh 进程继承——从图形会话里跑 dsh 才能采到屏。

## bundle 本体是纯数据包

`package.json` + `cordis.patch.yml` 两个文件就是全部源码，没有 JS 代码（cordis
composition 行引用的是上面两个 `@deepseek-ai/*` 包，不是本包）。因此：

- `npmDeps = null;` + `npmConfigHook = pkgs.emptyDirectory;` + `dontNpmBuild = true;`
  （同 dsh-headless-display，理由见其 AGENTS.md）。
- 自定义 `installPhase`：拷两个源文件 + 解两个 npm tarball 进
  `$out/lib/node_modules/{dsh-cua-driver,@deepseek-ai/*}`。
- `src = ./.;` 本地目录即源码，无 fetchFromGitHub。

## 验证

```
nix build .#dsh-cua-driver
nix eval .#dsh-cua-driver.passthru.dshBundle   # 应为 true
```

挂进 nix-config 后，`dsh --profile nix-tui` 启动时 composition 里应出现
`computer-use` 与 `cua-driver-mcp` 两行，模型侧工具命名空间为
`mcp__cua-driver-mcp__*`（`cua-driver list-tools` 可对照）。
