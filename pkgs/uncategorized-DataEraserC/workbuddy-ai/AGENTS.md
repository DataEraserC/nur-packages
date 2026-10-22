# workbuddy-ai 打包经验

国际版（`www.codebuddy.ai`）WorkBuddy 的独立包。上游**没有**可下载的国际版 Linux 产物，本包用国内版 deb 的同一份二进制，把 CLI 产品配置指向国际部署。

## 为什么不能直接换下载地址

- `https://www.workbuddy.ai/v2/update?platform=workbuddy-linux-x64-deb` 仍然返回 `5.5.2.37849279`，但它给的 `download.codebuddy.ai/.../WorkBuddy-linux-x64-deb-5.5.2.37849279-910352f0.deb` 已是 **404**（国内包同路径 200）；`download.codebuddy.cn` 上也没有这个版本。
- 其它平台名（`workbuddy-linux-x64-appimage`、darwin/win 系列）要么 `invalid platform`，要么 `no upgrade config found`；`download.codebuddy.ai` 的 COS 不允许 ListBucket，无法枚举真实文件名。
- 结论：国际版 Linux 二进制在上游已断供，只能复用国内版二进制。

## 改动点只有 `cli/product.json`

国际版与国内版的差异全在这一个文件（`resources/app.asar.unpacked/cli/product.json`，376 KB，含 prompts/agents/tools 等）：

```jq
.endpoint = "https://www.codebuddy.ai"   # 原 https://www.workbuddy.cn
| .isOversea = true                      # 该字段国内版默认缺失
| .dataFolderName = ".workbuddy-ai"      # 原 .workbuddy，避免与国内版共用状态
```

`productFeatures.InternationalLogin` 在国内版里本来就是 `true`、`authentication.attributes.externalDomain` 也含 `www.codebuddy.ai`，所以鉴权域名不需要改。

## 为什么不用环境变量覆盖

`product.json` 自己声明了 `productConfigPathEnv = ACC_PRODUCT_CONFIG_PATH`、`productConfigEnv = [ACC_PRODUCT_CONFIG_V3, ...]`，但那是**给 agent CLI 子进程**的（日志：`[WorkbuddyProductConfig] Spilled oversized ACC_PRODUCT_CONFIG_V3 … to avoid execve E2BIG`）。桌面主进程的 `UpdateService` 直接从 `resourcesPath/app.asar.unpacked/cli/product.json` 读文件，实测：

| 尝试 | 更新请求实际命中 |
|---|---|
| `ACC_PRODUCT_CONFIG_V3='{"isOversea":true}'` | `www.workbuddy.cn` |
| `ACC_PRODUCT_CONFIG_V3='{"isOversea":true,"endpoint":"https://www.codebuddy.ai"}'` | `www.workbuddy.cn` |
| `ACC_PRODUCT_CONFIG_PATH=/tmp/intl-product.json`（已改 endpoint） | `www.workbuddy.cn` |
| `--product-config-path=/tmp/intl-product.json` | `www.workbuddy.cn` |

所以必须就地改文件 → 必须重新铺一遍应用树（1.6 GB），不能 symlink 复用：Electron 的 `process.resourcesPath` 取自可执行文件的**真实路径**，symlink 进另一个 store 路径会让它继续读国内版的 `product.json`（与 `lobsterai-unwrapped` 的同类坑一致）。

## 并存的命名

- `pname = "workbuddy-ai"`、`bin/workbuddy-ai`、`share/applications/workbuddy-ai.desktop`、图标 `workbuddy-ai.png`：与国内版 `workbuddy` 同名会互相 shadow。
- `overrideAttrs` 复用 `workbuddy` 的全部打包逻辑（dpkg 解包、koffi 裁剪、ozone flag、`--no-sandbox`），版本自动跟随国内版，因此**不要**给它加 `passthru.updateScript`——国际站的更新接口指向的是不存在的产物。

## 验证方式

```shell
# 1. 配置真的改了
jq -r '.endpoint, .isOversea, .dataFolderName' \
  $(nix build --no-link --print-out-paths .#workbuddy-ai)/opt/WorkBuddy/resources/app.asar.unpacked/cli/product.json

# 2. 启动后看更新请求打到哪个域（xvfb 下跑 30-50s，无需登录）
xvfb-run -a timeout -s TERM 45 workbuddy-ai --no-sandbox 2>&1 | grep 'Checking for updates'
# 期望 https://www.codebuddy.ai/v2/update?...
```

未验证项：`isOversea: true` 是否被 daemon 采纳（影响 UI 语言与登录页默认区域）。本地没有国际站账号，只能确认端点切换；若登录后 UI 仍是中文，说明该字段由云端下发，需要另找开关。
