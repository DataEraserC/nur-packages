# codearts 打包经验

- **保持上游 `libexec/codearts/{codearts,bin/codearts}` 布局**：归档里只有 `agentkernel`（154MB 的 Bun ELF）和启动脚本 `codearts`，脚本用 `BASH_SOURCE` 推出 `SCRIPT_DIR` 再 `exec "$SCRIPT_DIR/bin/codearts"`。因此二进制必须装到 `$out/libexec/codearts/bin/codearts`，脚本装到 `$out/libexec/codearts/codearts`，再由 `makeWrapper` 生成 `$out/bin/codearts`；直接 symlink 会让 `BASH_SOURCE` 变成 `$out/bin/codearts`，`SCRIPT_DIR` 错位。
- **fixup 的 patchShebangs 不会改 libexec 里的脚本**：上游脚本 shebang 是 `#!/usr/bin/env bash`，实测 fixupPhase 后仍是原样（运行报 `/usr/bin/env: bad interpreter`）。需在 installPhase 里 `substituteInPlace ... --replace-fail '#!/usr/bin/env bash' '#!${stdenv.shell}'`。
- **干净环境需要显式 PATH**：versionCheckHook 用 `env --ignore-environment` 执行，脚本里的 `dirname`/`cd` 会找不到；wrapper 要 `--prefix PATH` 加 `coreutils`（顺带 `bashInteractive`、`git`、`ripgrep` 供 agent 运行时用）。
- **版本检查要保留 HOME**：`--version` 由 Bun 运行时处理，会写 `$HOME/.cache`/`$HOME/.local/state/codeartsdoer`；配合 `writableTmpDirAsHomeHook` + `versionCheckKeepEnvironment = "HOME"` 才能通过。
- **版本探测用 versioninfo JSON**：`codearts_cli_versioninfo_v1.0.json` 列出全平台 URL，脚本按 `.os == linux and .arch == x64/arm64` 过滤（排除 `x64-baseline`、`x64-musl` 等变体），版本号从 URL 的 `codearts-install-<ver>-linux-x64.tar.gz` 解析。
- **Bun 二进制同样 `dontStrip = true;`**（同 codebuddy，strip 会删掉段外 payload）。
