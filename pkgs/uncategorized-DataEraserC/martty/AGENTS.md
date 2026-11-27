# martty

上游 `martty` 0.3.3（MIT）是 Node CLI + 预编译 native painter 的 ACP 终端客户端；`xiaohuanxiong-acp` 用它提供 WebMux 的 hybrid TUI。

- **用 `buildNpmPackage`，但不要跑 `npm run build`**：tarball 已带构建产物，设 `dontNpmBuild = true`；`npmFlags = [ "--omit=dev" ]` + `dontNpmPrune = true` 只装运行期依赖。
- **`package-lock.json` 必须提交**：tarball 不自带 lock，用官方 registry 生成；`update.sh` 会重新生成 lock 并更新 `npmDepsHash`。lock 约 519 KB，超过 pre-commit 默认 500 KB 上限，已在 `flake-modules/lantian-pre-commit-hooks.nix` 把 `check-added-large-files` 调到 1024 KB。
- **native 模块要 `autoPatchelfHook`**：`node-pty` 等预编译 `.node` 需要 `autoPatchelfHook` + `stdenv.cc.cc.lib`；`postInstall` 删除非本机 prebuild（只留 linux-x64/arm64）和 musl 目录，并用 `[ -d ... ]` 守卫，因为 `--omit=dev` 可能没装 node-pty。
- **`MARTTY_HOME` 必须显式传**：不设会写 `~/.martty` / `~/.oma`，与桌面或其它实例串状态；`xiaohuanxiong-acp` 在 exec 前注入。
- 验证：`martty-cli --version`；`--check-runtime --agent <box-agent-acp>` 能完成 initialize 即通过。
