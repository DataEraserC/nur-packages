# codebuddy 打包经验

- **Bun 单文件可执行不能 strip**：上游原生发布物 `codebuddy-code_Linux_<arch>.tar.gz` 里是 148MB 的 Bun 编译产物，业务 JS 在 ELF 段之外的 payload 中。`strip`（stdenv 的 fixupPhase 默认开启）会把 payload 删掉，二进制退化成裸 Bun CLI：`--version` 打印 Bun 帮助而不是 `2.168.3`，versionCheckHook 随之失败。必须 `dontStrip = true;`（实测 `patchelf --set-interpreter` 本身不会破坏 payload，只有 strip 会）。
- **版本探测走 COS 文本端点**：`https://acc-1258344699.cos.accelerate.myqcloud.com/@tencent-ai/codebuddy-code/releases/latest` 直接返回版本号（如 `2.168.3`），不要用 api.github.com（匿名限流）。下载 URL 为 `.../releases/download/<version>/codebuddy-code_Linux_{x86_64,arm64}.tar.gz`，哈希应与同目录 `checksums.txt` 一致。
- **多平台源文件不要命名为 `sources.json`**：`helpers/update.nix` 的 `usesSources` 启发式会按文件内容里的 `sources.` 子串把整包跳过（`./sources.json` 也会命中），导致 `passthru.updateScript` 永不执行。本包改用 `release.json` + `release` 绑定规避，同时保留自定义 `update.sh`（多平台 URL/哈希各不相同，`nix-update` 无法维护）。
