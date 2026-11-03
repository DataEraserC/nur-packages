# SakuraFrp 打包笔记

上游：<https://www.natfrp.com/>（闭源预编译，`licenses.unfree`）。七个架构的
`natfrp-service` + `frpc` 都从同一镜像取：`nya.globalslb.net/natfrp/client/
launcher-unix/<version>/`，`latest/` 只是同内容的软链目录，所以版本探测走目录列表
（`grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1`），不解析 `latest`。

SakuraFrp 是境内服务，需要实名 KYC，镜像对境外网络基本不可用：回源失败给
Cloudflare 521，大文件传输中途被 RST（13 MB 的 tar.zst 常只到 4 MB，`nix store
prefetch-file` 报 `HTTP error 200 (curl error: Stream error in the HTTP/2 framing
layer)`），连续请求会被限流成 429 `请求过于频繁，请 1 小时后再试`。GitHub 的 runner
在境外，所以每周 auto-update 都在这上面翻车——而包本身没问题。

## 更新脚本的三条判定

上游会原地重发同版本 tarball（3.1.8 重发过，七个哈希全漂），所以每次运行都要重算
全部哈希，不能只在版本变化时算。但「重算失败」有两种含义，必须分开：

- prefetch 每个 URL 重试 3 次（递增退避）后才算失败
- `HTTP error 404/410`：上游删档/改名 → 硬失败，哈希必须重新钉
- 其他（截断、429、5xx、超时）且版本未变 → 告警 + `exit 0`，**不写文件**、也不跑
  末尾的验证构建；版本变了 → 硬失败（拿不到新哈希就不许提交）
- 索引页拿不到 → 跳过本次运行；索引拿得到但没有版本号（上游改了目录结构）→ 硬失败

实测 2026-11-03：从境外网络 prefetch 七个 URL 全部失败，脚本按预期告警后退出 0，
`SakuraFrp.nix` 一字节未动。
