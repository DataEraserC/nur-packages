# webmux-acp 打包经验

在 `../webmux` 之上用 `overrideAttrs` 叠加 ACP agent 适配器：上游把 agent 表写成源码里固定的 `NewRegistry(...)` 列表，官方没收录的 CLI 就只能靠本地补丁让它"被认出来"。`webmux` 本体保持零补丁、继续跟随 nix-update，所有本地补丁只活在派生包里。

本包与 `codebuddy-acp` 是两层不同的事，别混淆：

| 层 | 归属 | 职责 |
|---|---|---|
| CLI 的 ACP 能力缺口（`session/list`） | `codebuddy-acp` 包 | 在 CLI 外面套 stdio 代理补齐协议能力 |
| webmux 认识这个 agent | 本包（webmux 补丁） | 告诉 webmux "这个命令是 agent、怎么起 ACP、参数怎么分类" |

## 现有补丁

- `patches/codebuddy-agent.patch`：新增 `internal/agentprofile/codebuddy/codebuddy.go`（92 行的 adapter），并在 `internal/agentprofile/agents/agents.go` 里加一行 import、一处 `NewRegistry(...)` 参数
- 不碰 `internal/hybrid/` 的任何判据。早期为绕过 `session/list` 直接放宽 `eligibility.go`/`link.go` 的做法已废弃——缺口归 `codebuddy-acp`，webmux 侧只保留"认识这个 agent"这一件事

## 新增一个 agent 适配器

1. 在 `patches/` 下放一个只含该 agent 的补丁（新文件 + `agents.go` 的两行），与已有补丁不重叠，便于逐个失效、逐个重做
2. 在 `default.nix` 的 `patches` 列表里追加一行
3. 不需要新包：这个包的语义就是"带本地 agent 适配器的 webmux"，`pname` 也不随 agent 改名

## 已知脆弱点

- **版本 bump 时补丁大概率需要重做**：`agents.go` 的 import 块与 `NewRegistry` 单行是 nix-update 之后最容易变的地方。`patch -p1` 报 hunk 失败就按 `AGENTS_downstream.md` 的「上游补丁失效时的重新生成方法」，在解包的新源码上重放这两个文件的变换再 `diff -u` 生成（补丁头改回 `a/`、`b/`，新文件用 `--- /dev/null`）
- **上游随时可能自己收录这些 agent**：`internal/launch/presets.go` 里已经有 `CodeBuddy Code` 预设，只缺 hybrid 适配。上游合入后对应补丁要删掉，不要留着重复注册（`NewRegistry` 对重复 name 直接 panic）

## overrideAttrs 的必设项

- **`pname` 必须改**：沿用 `webmux` 会让两个派生同名不同内容，store 里无法区分，profile 冲突时也看不出装的是哪个
- **`passthru.updateScript = null`**：`webmux` 的 passthru 带 `nix-update-script {}`，继承下来会让自动更新去改本包的 `version`——而这个包没有自己的版本字面量（版本随 `webmux` 走），只会产出错乱结果。清空后 `helpers/update.nix` 直接跳过，`webmux` 升版本时它自动跟随
- **不要补 `versionCheckProgram`**：`webmux` 的 `meta.mainProgram = "webmux"` 会被继承，`versionCheckHook` 优先用 `NIX_MAIN_PROGRAM` 解析成 `$out/bin/webmux`，因此 `pname` 改成 `webmux-acp` 也不影响安装检查
- `vendorHash` 不用重算：补丁只 import 内部包

## 验收

```bash
nix build .#webmux-acp
out=$(nix build .#webmux-acp --no-link --print-out-paths)
$out/bin/webmux --version            # webmux 0.12.1（版本号跟上游，不带包名后缀）

# 用独立 state_dir 起一个临时实例
mkdir -p /tmp/wm-verify/state
cat > /tmp/wm-verify/config.toml <<'EOF'
listen = "127.0.0.1:1111"
token = "<43 字符以上的 token>"
EOF
XDG_STATE_HOME=/tmp/wm-verify/state $out/bin/webmux serve --config /tmp/wm-verify/config.toml --listen 127.0.0.1:1111 &

curl -s -X POST -H 'Authorization: Bearer <token>' -H 'Content-Type: application/json' \
  -d '{"cmd":["codebuddy"]}' http://127.0.0.1:1111/api/launch-configs/hybrid-support
# → {"supported":true,"agent":"codebuddy",...}
```

完整链路（终端起会话 → 切聊天）还需要 PATH 里有 `codebuddy-acp` 包，并且启动配置带 `hybrid: true`。
