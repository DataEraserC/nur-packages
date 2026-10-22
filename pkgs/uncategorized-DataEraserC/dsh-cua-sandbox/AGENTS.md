# dsh-cua-sandbox 打包笔记

上游：<https://github.com/trycua/cua>（MIT）。Bundle 版本跟随 cua-cli
（`cua-sdk-v0.7.0`），`nix-update --flake --version-regex '^cua-sdk-v(.*)$'`。

## 结构：只挂 kernel 自带的 mcp-client，不写 wrapper JS

`cordis.patch.yml` 单行 insert，`name` 直接指
`@deepseek-ai/dsh-mcp-client`（kernel 的通用 MCP 客户端插件，导出
`{ Config, apply, inject, name }`，Config 覆盖 command/args/env/stdio）。
`linkKernelNodeModules` 把 kernel 的 node_modules 链进本 bundle 包，
该包因此可解析，peers（cordis/schemastery）也落到 kernel 唯一实例。

对比 dsh-cua-driver：那个包挂的是 harness 的 experimental provider
（要注册 computerUse 独占槽、要从 cohort 解两个 tarball），本包什么都不用
解——这也意味着**harness 升级无需重新钉任何 hash**，mcp-client 与 kernel
同 derivation，天然版本匹配。

## 命名空间隔离

- `serverName: cua-mcp` → 模型看到 `mcp__cua-mcp__*`（沙盒面）
- dsh-cua-driver 的 `cua-driver-mcp` → `mcp__cua-driver-mcp__*`（本机面）

两个 serverName 不能撞：mcp-client 的 activeServerNames 按 owner 作用域
查重，撞名会让第二个实例激活失败。

## 运行期

- `runtimeDeps = [ cua-cli ]` 把 NUR 的 cua-cli 钉到 dsh 启动器 PATH，
  cordis.patch.yml 里 `command: cua` 走 PATH 解析，不烤绝对路径。
- 子进程 env = 父进程 scrub 后的环境（HOME/XDG_RUNTIME_DIR 都在）+
  行内 `env:` 追加；rootless podman socket 在
  `$XDG_RUNTIME_DIR/podman/podman.sock`，是 cua-vmm 的 well-known 候选，
  无需写死路径。
- `failOnStartupError` 留默认 false：`cua mcp` 启动不依赖容器引擎
  （无 podman 时 initialize + tools/list 照常），引擎缺失只在具体调用时报错。

nix-config 侧：dsh 模块把它加进 extraBundles，podman + 用户级
podman.socket 也由该模块启用；skills 软链进 `~/.dsh/skills/`。
