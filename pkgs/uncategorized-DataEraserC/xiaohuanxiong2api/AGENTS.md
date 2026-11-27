# xiaohuanxiong2api（xhx2api 小浣熊 OpenAI 兼容反代）

上游：<https://github.com/haoxinyu1/xiaohuanxiong2api>（MIT）。纯 Go 标准库、无第三方依赖（`vendorHash = null`），二进制名 `xhx2api`，包名沿用仓库名。

## 打包要点

- **Go module 在 `src/` 子目录**：`go.mod` 与 `cmd/xhx2api` 都在 `src/` 下，用 `sourceRoot = "source/src"` 进入模块根；`config.example.json` 在仓库根，安装时用 `${finalAttrs.src}/config.example.json` 引用。
- **不要设 `subPackages`**：唯一 main 包是 `cmd/xhx2api`，不设也会装出 `$out/bin/xhx2api`；设了反而让 `go test` 只测该子包、`internal/` 下的单测静默跳过（见 `../_docs/AGENTS.md` 的 Go 包一节）。
- **没有 `--version`/`-version` 旗标，不能加 `versionCheckHook`**：版本只有两个出口——启动日志行 `[main] 版本=… 监听=…`（`cmd/xhx2api/main.go` 的 `printStartup`）与 `/healthz` 返回 JSON 的 `version` 字段，两者都要求服务真正启动。构建期用 `-ldflags -X xhx2api/internal/version.Version=${finalAttrs.version}` 注入（与上游 Dockerfile 同一变量）。
- **上游无 tag**：`unstableGitUpdater { hardcodeZeroVersion = true; }`，版本为 `0-unstable-<HEAD committer date>`。

## 运行时形态（排障用）

- 配置是 JSONC（`//`、`/* */`、尾逗号；未知键直接启动失败）。`-config` 默认 `./config.json`，`XHX_CONFIG` 优先；`XHX_LISTEN`/`XHX_API_KEY`/`XHX_ADMIN_API_KEY` 覆盖对应字段。
- 状态文件默认相对 **CWD**：`accounts.file`=`./data/accounts.json`、`models.catalog_cache_file`=`./data/model_catalog.json`、`checkin.history_file`=`./data/checkin.json`。程序会自己 `MkdirAll` 父目录，所以要在可写目录运行，或在配置里改用绝对路径。
- 管理面板 `/admin` 经 `go:embed` 打进二进制，不需要额外文件；`xhx2api -healthcheck <url>` 只发一次 GET（2xx 退出 0，否则 1），适合 systemd/容器探针。
- 最小启动实测（`{"listen":"127.0.0.1:39066","checkin":{"enabled":false}}`）：`/healthz` 返回 `{"status":"ok","version":"<ldflags 注入值>"}`，`/admin` 200。
