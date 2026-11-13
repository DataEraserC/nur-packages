# WebMux / CodeBuddy / ZCode ACP 下游需求与升级闸门

本文件是 DataEraserC 下游对 WebMux 外部 ACP、`webmux-acp`、`codebuddy-acp`、`zcode-acp` 与 nix-config 接线的单一需求源。修改或更新这些组件前先读本文件；完成后逐项记录验收结果。包级 `AGENTS.md` 只保留实现经验和指针，不复制本文件。

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

验收条件：0 个或 2 个匹配 child 均拒绝；无关 child 不影响唯一匹配；身份与 cwd 取被选中的 native child，不取 launcher。

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
| nix-config             | CodeBuddy 实例声明、state compatibility、WebMux JSON 与 NUR pin                                            | 对应 module、host 与 focused test                               |
| 本文件                 | 跨层不变量、升级顺序与验收矩阵                                                                             | 本文件；其它 `AGENTS.md` 只保留触发指针和本地实现经验           |

WebMux upstream 不承载下游实例；NUR 不手工维护第二份实现；nix-config 不内嵌包实现；包级指南不复制本文件的规范正文。

## 4. NUR 包与固定源码来源

### PKG-01：`webmux` 与 `webmux-acp` 共用构建与依赖基线

主 `webmux` 与 `webmux-acp` 必须取同一 version、frontend pnpm deps、Go vendor deps 和完整构建定义。主包源码固定到审计过的 upstream base；`webmux-acp` 把 source 原子化替换为从该 base 延伸的固定 overlay tip，不复制或漂移主包构建逻辑。

当前基线（更新时整行一起改）：

| 项目                     | 值                                                    |
| ------------------------ | ----------------------------------------------------- |
| version                  | `0.14.5-unstable-2026-11-11`                          |
| upstream rev             | `4c9589b85aad3987953cd3037eee7c90bd9f43fe`            |
| upstream source hash     | `sha256-UvJ0MqPHfLl17NkGuIlyTCnhMyFtXn0fmP3jmoIDIko=` |
| downstream overlay tip   | `f0bb66ed27a24d5ee74b2cd3b0dc45e1723e1ba9`            |
| downstream source hash   | `sha256-vuPOPvvL8K2NIRuADooaYssQb7QQ/k3NV31whg77jk8=` |
| pnpm hash                | `sha256-AJEflSNtB60DwyJHkUM5i8Ju1DrsOULfC1MORuZLErU=` |
| vendor hash              | `sha256-8jgAcb9znAtAlDfwuBD5+qTimc3mwoCRZ38i6pHr/d4=` |

### PKG-02：ACP source 等于一个可审计的匿名下游 overlay 范围

`webmux-acp` 必须直接固定 `mzdluo123/webmux` 中可解析的 downstream overlay tip 及其 Nix source hash，不携带本地 patch。该 tip 必须由公开 fork `desktop-tools-which-may-be-useful/webmux` 的 `feat/downstream-overlay-v0.14.5` advertised branch 保留，更新 pin 前用公开 HTTPS `git ls-remote --heads` 验证 branch 精确指向 tip。`downstream/ownership.json` 固定表中的 upstream rev，并分类该 base 到 tip 的所有新增和修改路径；ownership checker 还必须证明 base 属于 canonical upstream history。范围内每个 commit 都必须只有一个 parent、连续可追溯，并使用仓库局部身份 `anonymous <anonymous@users.noreply.github.com>` 与 WebMux Conventional Commit 规范；不得含真实身份、主机路径、私有部署名、会话/任务 ID、协作者 trailer 或下游 CodeBuddy/multi-instance 内容。

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

`zcode-acp` 包公开 `bin/zcode-acp` 与 `bin/zcode-acp-server`（同一 dist 入口，argv 语义同上游 npm 包 `zcode-acp-server`）。vendor ZCode CLI 的公开命令名是 `zcode-cli`（`zcode-cli` 包），与桌面包的 `bin/zcode`（GUI 启动器）并存且互不遮蔽；两个名字都必须能上 `environment.systemPackages` 供 PATH 解析（multi-instance 按 `command -v` 解析 executable）。适配器自身仍通过 wrapper 注入的 `ZCODE_BIN` 定位 vendor CLI，不得依赖用户 PATH 上的任何 `zcode`。

### ZC-02：vendor CLI 来自桌面 AppImage，版本与 GUI 同步；无 TUI

`zcode-cli` 从 `zcode` 桌面包（GUI AppImage）的 `resources/glm/zcode.cjs` 提取，复用其 src 与版本，CLI 与 GUI 单一版本源。CLI 自身版本号（`zcode-cli --version`，如 `0.17.1`）与 GUI 版本（`3.x.y`）不同，因此 `zcode-cli` 不得使用 versionCheckHook，安装检查只验证 `--version` 退出 0 且输出非空。上游没有官方 Linux CLI tarball 分发（`ZCODE_DIST_BASE_URL` 是自建分发机制），不得改用社区第三方重打包（`@ljwei-stak/zcode-cli`、`zcode-app-cli`、ZCode-rs 等）。

AppImage 内的 glm bundle 是 desktop-agent 子集：`app-server`（headless 协议）、`-p` 无头模式、`login/logout`、`commands/skills/plugins/doctor` 可用；**全屏 TUI 不可用**——TUI 需要 `@zcode/tui`，它只存在于上游独立发行版（`build:zcode` 产出的 SEA / staged runtime，含 runtime node_modules），AppImage 里任何位置都没有该包，GUI 自身也从不运行 TUI。provider 资产（`resources/config/provider/zcode-builtin.json`）同样不在 glm 内，必须复制到 `glm/provider/` 才能通过启动时的候选路径解析。

### ZC-03：peer 依赖落地与运行时 node_modules

`zcode-acp` 的 dist 在运行时 import `zod`，但上游把它声明为 peerDependency，pnpm 的 `--prod` 安装与 prune 会丢弃 peer。打包必须在安装阶段把 zod 提升为 regular dependency：package.json 与 pnpm-lock.yaml importer 同步修改（保持 `--frozen-lockfile` 可用），再 `rm -rf node_modules && pnpm install --frozen-lockfile --prod --offline` 重装生产 node_modules，并随产物发布、与 dist 同级以满足 ESM 解析。dist 的版本号在运行时从同目录 `package.json` 读取，必须一并安装。

### ZC-04：nix-config 接线

- canonical multi-instance app key：`zcode-acp`（executable `zcode-acp-server`，ACP 用）与 `zcode-cli`（executable `zcode-cli`，headless CLI 用）；两者共享 `stateDirectoryKey = "zcode-cli"` 与 `paths = [".zcode"]`。这些 app 是未来接入的脚手架，本身没有桌面入口。
- **WebMux 混合模式对 zcode 结构性不可用，不得声明 acpAgents**：WM-ACP 契约的 `match`/`resume` 都是 TUI 表单（终端↔聊天切换以 TUI 为终端侧），而 ZC-02 已确认 AppImage bundle 无 TUI——声明了只会产出「启动即断」的死会话。zcode 的外部 ACP 消费方是 **acb**（通用 `acp_driver_acb` 预设按会话 spawn `zcode-acp-server`，恢复走 ACP `session/load`，全程无 TUI）。待上游独立 CLI runtime 从源码打包完成、`zcode-cli` 获得 TUI 后，再按 direct（`match = ["zcode-cli"]`）+ multi-instance（`launcher = "bwrap"`）形式恢复声明；`icon` 必须取 LaunchConfigIcon 支持的键（不在集合内的 icon 会让整个声明被加载器跳过），`processExecutables = ["node"]`。
- 桌面 GUI 是单一 `zcode` 包（CN 与国际版为同一 AppImage，仅登录区域不同）；`zcode-cn`/`zcode-intl` 不再作为独立包存在，multi-instance alias 保留 `zcode-intl` → `zcode` 兼容旧 CLI 名称。

## 7. nix-config 部署不变量

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

## 8. 升级流程

每次更新 WebMux、CodeBuddy vendor、对应 NUR 包或 nix-config 接线时按顺序执行：

1. 读取本文件，列出本次可能受影响的需求 ID。
2. 更新主 `webmux` 基线与三类固定输出哈希；证明 updater 不会选择无关 tag。
3. 在该 base 上按逻辑重放仍需保留的 downstream overlay commits；运行 upstream tests/docs/architecture/user-story 与 ownership gates。
4. 做隐私检查后发布固定 overlay tip；验证 base/tip ancestry、逐 commit 身份与 scope，并把 tip 与 Nix source hash 写入 `webmux-acp`。
5. 构建并测试 `webmux`、`webmux-acp`、`codebuddy-acp`；检查公开 `bin/`。
6. 提交 NUR 后更新 nix-config NUR lock；运行 focused eval、格式化、module tests 与目标 host build。
7. 在提交/PR 摘要按需求 ID 记录 pass、环境性限制和未运行项。任何未验证项保持未完成，不能用“构建成功”概括。

## 9. 最低验收矩阵

| 需求          | 自动化证据                                                                                                                                                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| WM-ACP-01..03 | exact match/path first token/no scan/empty args/connector per command tests                                                                                                                                                     |
| WM-ACP-04     | env bash、bare bash、zsh startup argv 与 fd 3 tests                                                                                                                                                                             |
| WM-ACP-05     | native root 与 launcher 0/1/2 matching child、child cwd tests                                                                                                                                                                   |
| WM-ACP-06     | strict JSON、limits、skip/conflict/no panic、constructor wiring、service render round-trip tests                                                                                                                                |
| PKG-01..04    | build definition/dependency identity、base/tip ancestry、逐 commit 身份、range scope/source hash、Nix builds、explicit internal Go tests                                                                                   |
| CB-01..03     | dispatch/argv/env/transport ordering/initialize/session-list tests、`bin/` listing                                                                                                                                              |
| ZC-01..04     | `zcode-cli`/`zcode-acp` installCheck（`bin/` listing、`--version`、ACP initialize smoke）、focused Nix expected-output test（app keys、共享 state key、无 WebMux 声明）、target host build、真实 vendor ACP smoke（initialize/session/list）、`app-server --stdio` 启动健康 |
| NC-01..03     | focused Nix expected-output test（canonical app/CLI alias/old-key removal/exact bindings）、生产 spec runtime test（canonical/legacy/default/userDataDir）、shell syntax、module eval、target host build、state path assertions |

真实 ACP 切换 smoke 至少覆盖一次 direct binding 和一次 launcher binding：launch support → TUI session → ACP initialize/session/list/session/load → resume TUI。若环境无法运行真实 vendor CLI，应明确记录为未运行，不以 fake-agent 单测替代。
