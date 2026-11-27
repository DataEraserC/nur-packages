# WebMux / CodeBuddy / ZCode / Qoder CLI ACP 下游需求与升级闸门

本文件是 DataEraserC 下游对 WebMux 外部 ACP、`webmux-acp`、`codebuddy-acp`、`zcode-acp`、`qodercli`/`qoderclicn` 与 nix-config 接线的单一需求源。修改或更新这些组件前先读本文件；完成后逐项记录验收结果。包级 `AGENTS.md` 只保留实现经验和指针，不复制本文件。

## 1. 范围和术语

- **稳定 agent ID**：`WEBMUX_ACP_AGENTS` 顶层键，只用于持久化身份与 UI，不是命令名或进程名。
- **launch argv**：用户保存并由 TUI 启动的完整内层 argv。
- **ACP argv**：启动 stdio ACP server 的完整 argv。
- **resume argv**：恢复 TUI 的完整 argv 前缀；WebMux 追加 session ID。
- **native process**：TUI 最终运行的 agent 进程。
- **launcher**：保持为 PTY 根进程、把 native process 作为直接子进程运行的可选程序。
- **connector**：需要另装并由 WebMux 检查/提示的 ACP 程序元数据；它不参与命令推导。

`multi-instance`、CodeBuddy 和 ZCode 是下游部署实例，不属于 WebMux 的通用领域模型。WebMux 上游源码、测试和文档使用虚构的通用示例。

## 2. WebMux 通用外部 ACP 契约

### WM-ACP-01：单一、通用、精确的声明入口

`WEBMUX_ACP_AGENTS` 是唯一外部声明入口。顶层对象按稳定 agent ID 保存 `Spec`；每条 command 同时声明完整 `match`、`acp` 和 `resume` argv。

验收条件：

- 不存在第二张 wrapper 表、固定 wrapper 参数个数或 per-instance 可执行文件。
- WebMux 不理解 launcher 的业务语义，也不包含 CodeBuddy 或本地部署专用分支。
- declared agent 只靠完整 binding 识别，不在任意 argv token、label 或 shell 文本中扫描 agent 名。
- built-in adapter 继续使用自己的 executable/options parser；仅可对结构化识别出的既有 wrapper 形态给出诊断。

### WM-ACP-02：稳定 ID、命令、进程与安装元数据相互独立

`Spec` 必须明确声明非空 `processExecutables`；稳定 ID 不得隐式成为进程名或 launch executable。每条 command 可分别声明 `launcher` 与 `connector`。

`connector` 省略或为 `null` 表示无安装检测语义。存在时必须显式提供 executable、title、installCommand、HTTP(S) docsUrl，并可提供 verifiedVersion；WebMux 不从 `acp[0]` 推断 connector，因为 ACP argv 可从 `env`、解释器、绝对路径或 wrapper 开始。

验收条件：两条同 agent binding 可以拥有不同 connector/launcher；support、create、switch、start failure、missing notice、version notice 和 recheck 全部读取当前 command 的 connector。

### WM-ACP-03：argv 保真与精确匹配

- `match[0]` 是 executable basename；实际首 token 可为同 basename 的绝对/相对路径。
- 其余 token 和 argv 长度逐字相同；多一个参数、不同实例值或不同 wrapper 参数都需要新 binding。
- argv 始终以数组执行，不拼 shell command string。
- executable token 必须非空；其它 token 可以为空、含空格或以 `-` 开头；所有 token 禁止 NUL。
- ACP argv 按声明原样执行；resume 只在声明前缀末尾追加 session ID。

### WM-ACP-04：startup-file 外层与 fd 3 不变

通过“加载 shell 启动文件”保存的 `/usr/bin/env bash -ic`、bare `bash -ic` 或 `zsh -ic` 外层不属于 `match`。切换模式时只替换内层 argv，保留外层的原始拼写；ACP 继续使用 fd 3，避免启动文件输出污染协议流。

验收条件：TUI argv 与原始输入完全相同；ACP/resume argv 保留相同 outer prefix；ACP 使用 fd 3。

### WM-ACP-05：launcher 进程身份唯一

若 PTY 根进程本身是 native process，直接使用它。否则只有在根进程 basename 等于 command 的 launcher，且其直接子进程中恰好一个匹配 `processExecutables` 时才接受。

声明式 command 自带 operator 写下的启动 argv，因此它确认到的 native process 优先于 terminal signal 指向的另一个 agent；built-in session 仍按 signal 优先。signal 指向别的 agent 且进程身份不匹配本 command 时继续报 `unknown_agent`。

验收条件：0 个或 2 个匹配 child 均拒绝；无关 child 不影响唯一匹配；身份与 cwd 取被选中的 native child，不取 launcher；声明 agent 在 fake agent 广播 built-in profile 的 `app` 时仍能完成 terminal→chat 切换。切换用例走真实进程链，而进程事实需要 machine identity，所以该用例在无 machine identity 的构建沙箱里显式 skip，只在有进程事实的机器上给出证据；纯逻辑的 child 选择用例不受此约束。

### WM-ACP-06：严格、有界、显式加载

- JSON 使用严格 decoder：未知字段、重复或大小写折叠冲突字段、尾随数据都拒绝。
- 文档总大小、agent 数、每 agent command 数、每 argv token 数和 token 字节数都有上限。
- 整份文档无效时 built-ins 保持可用；单个无效/冲突 agent 记录安全 warning 后跳过。
- 跨 agent 重复 binding、覆盖 built-in binding 或可执行入口时跳过，不 panic。
- loader 是纯函数，不在 package `init()` 读取环境或改写全局 registry。
- `cmd/webmux` 在应用 launch environment 后读取变量，构造一个 registry，并把同一实例注入 session submit-delay、launch support/normalize、API chat support 与 hybrid service。
- `webmux service install` 持久化 `WEBMUX_ACP_AGENTS`；不持久化 token 等未批准环境变量，systemd/launchd 转义后须能无损还原 JSON。

## 3. 文件归属与单一事实源

| 层                     | 唯一职责                                                                                                   | 事实源                                                          |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| WebMux downstream branch | 通用 external ACP、hybrid-session 修复、ownership 治理及其通用测试与文档                          | 获准公共分支上的匿名连续提交范围与 `downstream/ownership.json` |
| NUR `webmux`             | upstream base 源码、前端/Go 依赖哈希与组合 updater                                                        | `pkgs/uncategorized-DataEraserC/webmux/default.nix`             |
| NUR `webmux-acp`         | 复用 `webmux` 构建定义，源码直接固定到审计 overlay tip，并扩大 check 范围                                  | `webmux-acp/default.nix`                                        |
| NUR `codebuddy-acp`    | CodeBuddy 专用双模式入口及 stdio ACP compatibility proxy                                                   | `codebuddy-acp/`                                                |
| NUR `qodercli` / `qoderclicn` | Qoder CLI 两个 edition 的上游二进制固定来源与更新闸门                                          | `qoder-cli-common.nix` 与各自 `release.json`、`update.sh`        |
| nix-config             | CodeBuddy/ZCode/Qoder CLI 实例声明、state compatibility、WebMux JSON 与 NUR pin                              | 对应 module、host 与 focused test                               |
| 本文件                 | 跨层不变量、升级顺序与验收矩阵                                                                             | 本文件；其它 `AGENTS.md` 只保留触发指针和本地实现经验           |

WebMux upstream 不承载下游实例；NUR 不手工维护第二份实现；nix-config 不内嵌包实现；包级指南不复制本文件的规范正文。

## 4. NUR 包与固定源码来源

### PKG-01：`webmux` 与 `webmux-acp` 共用构建与依赖基线

主 `webmux` 与 `webmux-acp` 必须取同一 version、frontend pnpm deps、Go vendor deps 和完整构建定义。主包源码固定到审计过的 upstream base；`webmux-acp` 把 source 原子化替换为从该 base 延伸的固定 overlay tip，不复制或漂移主包构建逻辑。

当前基线（更新时整行一起改）：

| 项目                     | 值                                                    |
| ------------------------ | ----------------------------------------------------- |
| version                  | `0.19.1-unstable-2026-11-28`                          |
| upstream rev             | `20743140a0b1559fdb1424e892ff7a64760e2229`            |
| upstream source hash     | `sha256-0aDgDamIMnlY4R5jOjhHaLxGT5BKgf/f9lwg4eLZ26Y=` |
| downstream overlay tip   | `4d3d8c3f4d93824fbbef318ed0b755b98a9611be`            |
| downstream source hash   | `sha256-ntQ8e4LQBUO6kX6IryzOn7O0Eiqz/GM+Din461Hkawc=` |
| pnpm hash                | `sha256-jeufMwHqygtsf2FdXQIN/okE2lyVjS+EjYy+2fxXGv4=` |
| vendor hash              | `sha256-3DGb4/ib8UVDke83n2lJtmAurgPnRc63gybQv+aWIxc=` |

`webmux-acp` 的 overlay 已 rebase 到 tag `v0.19.1`（upstream rev 即 `downstream/ownership.json` 的 `upstreamBase`），与主包共享前端依赖哈希与 Go vendor baseline；主包 updater 之后把 `webmux/` 推进到更新的 upstream HEAD，两者的依赖集合未变，但 acp 仍显式固定自己的 source、version 与这两类哈希，避免主包漂移时破坏冻结 tip 的可构建性。0.14.5 时期为兼容旧树而加的三个 override 已删除。

### PKG-02：ACP source 等于一个可审计的匿名下游 overlay 范围

`webmux-acp` 必须直接固定 `mzdluo123/webmux` 中可解析的 downstream overlay tip 及其 Nix source hash，不携带本地 patch。该 tip 必须由公开 fork `desktop-tools-which-may-be-useful/webmux` 的 advertised branch（当前为 `feat/external-acp-commands-v0.19.1`）保留，更新 pin 前用公开 HTTPS `git ls-remote --heads` 验证 branch 精确指向 tip。`downstream/ownership.json` 固定表中的 upstream rev，并分类该 base 到 tip 的所有新增和修改路径；ownership checker 还必须证明 base 属于 canonical upstream history。范围内每个 commit 都必须只有一个 parent、连续可追溯，并使用仓库局部身份 `anonymous <anonymous@users.noreply.github.com>` 与 WebMux Conventional Commit 规范；不得含真实身份、主机路径、私有部署名、会话/任务 ID、协作者 trailer 或下游 CodeBuddy/multi-instance 内容。

更新基线时：按逻辑重放仍需保留的 overlay commits，完成 WebMux 功能与 ownership 验证后同时更新 tip 与 source hash；验证 base/tip ancestry、逐 commit 身份、tree scope 与公开归档 hash，不从 patch 邮件头间接推导源码版本。

### PKG-03：主包 updater 同时更新三类哈希

主 `webmux` updater 先用 `unstableGitUpdater`（`tagFormat = "v*"`, `tagPrefix = "v"`）更新 version/rev/source，再用 `nix-update --version skip --no-src` 更新 vendorHash 与公开的 pnpmDeps hash。更新器必须忽略无关 `dev` tag；只更新 source 而留下依赖哈希是失败。

### PKG-04：测试范围覆盖新增 internal 包

主包 `subPackages = [ "cmd/webmux" ]` 会把默认 Go check 收窄。`webmux-acp` 必须显式运行 external ACP 所涉及的 internal tests，以及 terminal→chat 的 opt-in、无 capability 旧客户端、真实 HTTP query 与 CLI 路径回归；不能以主包构建成功代替新增功能测试。

## 5. `codebuddy-acp` 产品契约

### CB-01：唯一公开入口

产物只公开 `bin/codebuddy-acp`，不得公开或 PATH-shadow `bin/codebuddy`。vendor CodeBuddy 作为闭包依赖，不公开第二入口。

### CB-02：非 ACP 行为等同 vendor CLI

不选择 stdio ACP 时，`codebuddy-acp` 用 `syscall.Exec` 进入 vendor CLI，保持 argv（含 argv[0]）、环境、TUI、print 与其它参数语义。只有 `--acp` 默认 stdio或显式 `--acp-transport stdio` 进入 proxy；flags 顺序无关，非 stdio或缺失 transport value 不得误入 proxy。

公开入口必须是直接 Go ELF；默认 vendor 路径由构建期 ldflags 注入，非空 `CODEBUDDY_ACP_REAL` caller override 优先。安装检查必须证明没有 shell wrapper/libexec proxy，并在未设置 override 时验证 vendor `--version`；不得用会改写 argv0 或注入环境变量的 wrapper 传递 vendor 路径。

### CB-03：proxy 只补 CodeBuddy 缺口

本包不是跨 agent 通用 proxy。它只：

- 转发 vendor CodeBuddy ACP；
- 在 initialize response 中补 `sessionCapabilities.list`；
- 本地实现 `session/list`，从 CodeBuddy transcript 恢复 ID/cwd/title/updatedAt；
- 其它 JSON-RPC 帧逐行透传。

会话时间使用 RFC3339Nano，cwd 从 transcript 内容恢复，数据根按以下三态跟随 CodeBuddy 配置：`CODEBUDDY_CONFIG_DIR` 未设置时使用 `$HOME/.codebuddy/projects`；设置为非空时使用其 `projects` 子目录；显式设置为空是无效的显式配置，`session/list` 返回空列表且不得回退默认 profile。

## 6. ZCode：`zcode-acp` 与 vendor CLI

### ZC-01：公开入口与 vendor CLI 注入

`zcode-acp` 包公开三个入口（同一 dist/TTY 分派）：`bin/zcode-acp-server`（stdio ACP server，无 TTY 或显式调用都进 server）、`bin/zcode-acp`（TTY 下进入 Martty 交互聊天 TUI，无 TTY 回落 server）、`bin/zcode-acp-resume <session-id>`（把 WebMux resume 追加的 session id 翻译成 `ZCODE_ACP_RESUME_SESSION` boot-resume 环境后打开 TUI）。vendor ZCode CLI 的公开命令名是 `zcode-cli`（`zcode-cli` 包），与桌面包的 `bin/zcode`（GUI 启动器）并存且互不遮蔽；相关名字都必须能上 `environment.systemPackages` 供 PATH 解析（multi-instance 按 `command -v` 解析 executable）。适配器自身仍通过 wrapper 注入的 `ZCODE_BIN` 定位 vendor CLI，不得依赖用户 PATH 上的任何 `zcode`。

### ZC-02：vendor CLI 来自桌面 AppImage，版本与 GUI 同步；官方 TUI 缺席

`zcode-cli` 从 `zcode` 桌面包（GUI AppImage）的 `resources/glm/zcode.cjs` 提取，复用其 src 与版本，CLI 与 GUI 单一版本源。CLI 自身版本号（`zcode-cli --version`，如 `0.17.1`）与 GUI 版本（`3.x.y`）不同，因此 `zcode-cli` 不得使用 versionCheckHook，安装检查只验证 `--version` 退出 0 且输出非空。上游没有官方 Linux CLI tarball 分发（`ZCODE_DIST_BASE_URL` 是自建分发机制），不得改用社区第三方重打包（`@ljwei-stak/zcode-cli`、`zcode-app-cli`、ZCode-rs 等）。

AppImage 内的 glm bundle 是 desktop-agent 子集：`app-server`（headless 协议）、`-p` 无头模式、`login/logout`、`commands/skills/plugins/doctor` 可用；**官方全屏 TUI 不可用**——它需要 `@zcode/tui`，只存在于上游独立发行版（`build:zcode` 产出的 SEA / staged runtime），AppImage 里任何位置都没有该包，GUI 自身也从不运行它。zcode 的终端侧交互由 `zcode-acp` 的 Martty TUI 承担（桥接器自带聊天界面，驱动同一 app-server 会话库）。provider 资产（`resources/config/provider/zcode-builtin.json`）同样不在 glm 内，必须复制到 `glm/provider/` 才能通过启动时的候选路径解析。

### ZC-03：peer 依赖落地与运行时 node_modules

`zcode-acp` 的 dist 在运行时 import `zod`，但上游把它声明为 peerDependency，pnpm 的 `--prod` 安装与 prune 会丢弃 peer。打包必须在安装阶段把 zod 提升为 regular dependency：package.json 与 pnpm-lock.yaml importer 同步修改（保持 `--frozen-lockfile` 可用），再 `rm -rf node_modules && pnpm install --frozen-lockfile --prod --offline` 重装生产 node_modules，并随产物发布、与 dist 同级以满足 ESM 解析。dist 的版本号在运行时从同目录 `package.json` 读取，必须一并安装。

### ZC-04：nix-config 接线

- canonical multi-instance app key：`zcode-acp`（executable `zcode-acp-server`，ACP 用）与 `zcode-cli`（executable `zcode-cli`，headless CLI 用）；两者共享 `stateDirectoryKey = "zcode-cli"` 与 `paths = [".zcode"]`。这些 app 是 multi-instance TUI 实例化之前的脚手架，本身没有桌面入口。
- WebMux binding（direct 形式）：`match = ["zcode-acp"]`（Martty 聊天 TUI，TTY 分派）/ `acp = ["zcode-acp-server"]` / `resume = ["zcode-acp-resume"]`（boot-resume 包装器）。终端侧是桥接器自带的 Martty TUI 而非官方 zcode TUI（后者待上游独立 CLI 从源码打包）；聊天侧经 `session/list` 发现同一会话库。`icon` 必须取 LaunchConfigIcon 支持的键（不在集合内的 icon 会让整个声明被加载器跳过）；`processExecutables = ["node", "bun"]`（TUI 会换手 bun --smol）。multi-instance 形式（`launcher = "bwrap"`）待 multi-instance 侧有 TUI 可跑后再加。
- zcode 的另一外部 ACP 消费方是 **acb**（通用 `acp_driver_acb` 预设按会话 spawn `zcode-acp-server`，恢复走 ACP `session/load`，全程无 TUI）。
- 桌面 GUI 是单一 `zcode` 包（CN 与国际版为同一 AppImage，仅登录区域不同）；`zcode-cn`/`zcode-intl` 不再作为独立包存在，multi-instance alias 保留 `zcode-intl` → `zcode` 兼容旧 CLI 名称。

## 7. Qoder CLI：`qodercli` 与 `qoderclicn`

### QC-01：版本源是 CLI 自更新通道，不是 npm

两个包是同一上游产品的两个分发 edition：国际版 `https://download.qoder.com/qodercli/channels/manifest.json`，中国版 `https://static.qoder.com.cn/qoder-cli-cn/channels/manifest.json`。该 feed 就是 `qodercli update` 轮询的清单，`.latest` 才是真正的最新发布版本；npm 包 `@qoder-ai/qodercli` 只是下载器包装，不得作为版本或产物来源（其 tarball 不含可构建源码，只提供 bootstrap）。

`update.sh` 只在 `.latest` 匹配 `^[0-9]+\.[0-9]+\.[0-9]+$` 时推进；按 `os == "linux"` 且 `arch` 精确等于 `amd64`/`arm64` 取资产并要求恰好命中一条（同 arch 还并列 `-musl` 变体，前缀匹配会双命中）；把每个平台的 `url` 与 `sha256` 写进本包 `release.json`。清单里的 `sha256` 是十六进制串，与 `nix store prefetch-file --json` 对同一 URL 报的 SRI 是同一摘要，直接 `nix hash convert --hash-algo sha256 --to sri` 换算，无需二次下载。写回后必须 `nix build ".#$UPDATE_NIX_ATTR_PATH"` 全量验证；无新版本时静默 `exit 0`，脚本可重复执行。

多平台多产物的版本与哈希写 `release.json` 而不是 `sources.json`：`helpers/update.nix` 的 `usesSources` 启发式会跳过表达式里出现 `sources.` 引用的包，写错文件名等于自动更新永久看不到它。两包共享 `qoder-cli-common.nix`，由它按 `stdenv.hostPlatform.system` 索引 `release.json`，缺平台 `throw`；该 helper 直接放在分组目录下，`createLoadPackages` 过滤所有 `.nix` 结尾条目，因此不会变成一个包（`maintainers.nix` 同理）。

### QC-02：Bun 单文件 ELF 的打包约束

上游资产是 Bun 编译的单文件可执行文件（约 200 MB），运行时 JS 载荷作为裸数据追加在 ELF 段之后：

- 必须 `dontStrip = true`：默认 `stripPhase` 会把 ELF 段之后的载荷当废尾截掉，几百 MB 产物削成十几 MB 的残桩。
- 需要 `autoPatchelfHook`：产物硬解释器是 `/lib64/ld-linux-x86-64.so.2`，NixOS 上不存在该路径；只改解释器，不用 `patchelf --set-rpath` 重排段布局。
- tarball 顶层直接是单个可执行文件（无版本目录），用 `sourceRoot = "."`。
- `--version` 打印与清单一致的版本号，可用 `versionCheckHook` 做安装检查。
- `meta.license = unfree`、`sourceProvenance = [ binaryNativeCode ]`，`platforms` 只列 `x86_64-linux`/`aarch64-linux`（清单里另有 darwin 资产，不由本包分发）。

### QC-03：CLI 自带 ACP server，不引入第二层包装

`qodercli --acp` / `qoderclicn --acp` 直接在 stdio 上服务 ACP（1.1.81 起；更早的构建只认 `--experimental-acp`），`--resume <session-id>` 回到同一二进制的 TUI。`initialize` 回报 `agentInfo.name` 为 `qoder-cli` / `qoder-cli-cn`，`sessionCapabilities` 含 `list`、`resume`、`fork`、`close`、`delete`，所以 chat 侧能发现并续用终端侧创建的会话。与 `codebuddy-acp` 必须自建 `session/list` proxy 不同，这里没有任何需要补的缺口，产物就应是上游二进制本身，不额外提供 wrapper、libexec 或改名入口。

状态是单一目录：国际版 `~/.qoder`、中国版 `~/.qoder-cn`，登录、`projects` 下的会话、skills 与 plugins 全在其下（同品牌的 IDE 与桌面 App 复用同一目录）。`qodercli update`/`rollback` 在 Nix 里禁用：store 是唯一二进制副本，自更新会往用户目录写第二份不受管理的二进制并造成版本漂移。

### QC-04：nix-config 接线

- module `modules.qodercli` 与 `modules.qoderclicn`（与包名一致，形状照 `modules.codebuddy-acp`）：默认取 pinned `nur-DataEraserC.legacyPackages.${system}.<pkg> or null`，启用时用 assertion 要求非 null。
- multi-instance app key `qodercli`（state key `qoder-cli`，paths `.qoder`）与 `qoderclicn`（state key `qoder-cn-cli`，paths `.qoder-cn`）：`executable` 留空即取 app key，`desktop = null` 表示 CLI-only、不生成启动器。state key 必须与同品牌桌面 app（`qoder`/`qoder-cn`）不同，CLI 登录不继承桌面账号。`persist` 写成纯字符串，让 `lib.unique` 把与桌面/IDE 条目同形状的声明折叠成一条 `preserveDirectories`，而不是把同一 `$HOME` 路径声明两次。
- WebMux 只声明 wrapped 形式：`launcher = "bwrap"`、`processExecutables = [ "qoderclicn" ]`（bwrap 的直接子进程就是 CLI 本身，没有 node/bun 换手）。不得再加 bare `qoderclicn` 直连声明——它已是 WebMux 内置 adapter（`qodercn`）的 executable，而 `match[0]` 命中内置 executable 的外部声明会被当作 shadow 整条丢弃，加直连形式等于删掉这个 agent。`icon` 必须取 LaunchConfigIcon 支持的键，未知 icon 会让加载器跳过整份声明。
- CN 实例数与 `modules.agent-accounts.desktopAccounts.qoder-cn` 对齐（2 个，各自 `multi-instance qoderclicn N login` 登录一次）；国际版与 `modules.qoder` 同状态：打包但不在 host 上启用，因此也没有 agent 声明。

## 8. nix-config 部署不变量

### NC-01：应用名、可执行文件与状态 key 分离

- 应用/module/可执行文件与 canonical multi-instance app key：`codebuddy-acp`；canonical `apps` 中不得保留 `codebuddy`。
- vendor 持久状态 key：`codebuddy`。
- 为 seed-once 旧启动配置保留 `aliases.codebuddy = "codebuddy-acp"` 这类 CLI-only alias；alias 必须复用 canonical app 的 executable/state/paths，不得复制 app、桌面入口或持久化声明。
- 保留 `.codebuddy`、`.local/share/CodeBuddyExtension` 与既有 multi-instance 状态根；迁移不得清空、改名或重建用户数据。
- multi-instance 数据模型显式保存 app、executable、state key 和独立 alias，不再假设这些名字相同。

### NC-02：WebMux 只消费通用声明

nix-config 通过一个 `WEBMUX_ACP_AGENTS` JSON 定义 direct、canonical wrapped 与 seed-once legacy wrapped 完整 argv；旧 binding 只兼容精确的已保存命令，不让 WebMux 推导 alias。wrapped binding 的 launcher 是实际 PTY 根进程，`processExecutables` 只列 proxy 在非 ACP 模式 `exec` 后的 vendor TUI 实际进程名，不列只存在于 ACP side 的 proxy 名。部署可出现 `multi-instance` 与 CodeBuddy；WebMux 通用实现不可出现这些专名。

### NC-03：包来源与旧配置兼容

- WebMux package 直接取 pinned `nur-DataEraserC.legacyPackages.${system}.webmux-acp`，不为改名创建本地 overlay。
- 已存在的 `launch-configs.json` 只由上游 seed-once 规则管理；迁移不得删除、逐项迁移或整体重写。旧 `multi-instance codebuddy 1` 由 multi-instance CLI alias 和同 argv 的 WebMux exact binding 兼容。
- NUR commit 完成后再更新 nix-config 的 NUR lock；配置和 lock 必须指向包含相同 pinned package 的提交。

## 9. 升级流程

每次更新 WebMux、CodeBuddy vendor、Qoder CLI、对应 NUR 包或 nix-config 接线时按顺序执行：

1. 读取本文件，列出本次可能受影响的需求 ID。
2. 更新主 `webmux` 基线与三类固定输出哈希；证明 updater 不会选择无关 tag。
3. 在该 base 上按逻辑重放仍需保留的 downstream overlay commits；运行 upstream tests/docs/architecture/user-story 与 ownership gates。
4. 做隐私检查后发布固定 overlay tip；验证 base/tip ancestry、逐 commit 身份与 scope，并把 tip 与 Nix source hash 写入 `webmux-acp`。
5. Qoder CLI 走各自 `update.sh`：从 edition 的 `channels/manifest.json` 取 `.latest` 与双平台资产，清单 `sha256` 换算成 SRI 后写 `release.json`，再 `nix build` 验证（见 QC-01）。
6. 构建并测试 `webmux`、`webmux-acp`、`codebuddy-acp`、`qodercli`、`qoderclicn`；检查公开 `bin/`。
7. 提交 NUR 后更新 nix-config NUR lock；运行 focused eval、格式化、module tests 与目标 host build。
8. 在提交/PR 摘要按需求 ID 记录 pass、环境性限制和未运行项。任何未验证项保持未完成，不能用“构建成功”概括。

## 10. 最低验收矩阵

| 需求          | 自动化证据                                                                                                                                                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| WM-ACP-01..03 | exact match/path first token/no scan/empty args/connector per command tests                                                                                                                                                     |
| WM-ACP-04     | env bash、bare bash、zsh startup argv 与 fd 3 tests                                                                                                                                                                             |
| WM-ACP-05     | native root 与 launcher 0/1/2 matching child、child cwd、declared command 对 foreign signal 优先级 tests                                                                                                                              |
| WM-ACP-06     | strict JSON、limits、skip/conflict/no panic、constructor wiring、service render round-trip tests                                                                                                                                |
| PKG-01..04    | build definition/dependency identity、base/tip ancestry、逐 commit 身份、range scope/source hash、Nix builds、explicit internal Go tests                                                                                   |
| CB-01..03     | dispatch/argv/env/transport ordering/initialize/session-list tests、`bin/` listing                                                                                                                                              |
| ZC-01..04     | `zcode-cli`/`zcode-acp` installCheck（`bin/` listing、`--version`、ACP initialize smoke）、focused Nix expected-output test（app keys、共享 state key、无 WebMux 声明）、target host build、真实 vendor ACP smoke（initialize/session/list）、`app-server --stdio` 启动健康 |
| QC-01..04     | `update.sh` 幂等 no-op、双平台 `nix build` 与 `--version` installCheck、真实 `--acp` initialize smoke（`agentInfo.name`、`sessionCapabilities`）、focused Nix expected-output test（module 开关、state key 与桌面端分离、spec 行、`preserveDirectories` 折叠、CN 两条 wrapped 命令、无直连声明） |
| NC-01..03     | focused Nix expected-output test（canonical app/CLI alias/old-key removal/exact bindings）、生产 spec runtime test（canonical/legacy/default/userDataDir）、shell syntax、module eval、target host build、state path assertions |

真实 ACP 切换 smoke 至少覆盖一次 direct binding 和一次 launcher binding：launch support → TUI session → ACP initialize/session/list/session/load → resume TUI。若环境无法运行真实 vendor CLI，应明确记录为未运行，不以 fake-agent 单测替代。
