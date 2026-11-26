# meoo2api-firefox（Firefox 登录 403「仅支持同源控制台请求」修复版）

上游：<https://github.com/LazyBonesLZY/meoo2api>（MIT）。本包是 `meoo2api` 的
`.overrideAttrs` 包装，只追加一个补丁，源码 pin、vendorHash、更新机制全部跟随
基础包 `pkgs/uncategorized-DataEraserC/meoo2api/`。

## 现象与根因（2026-11-27 实测，rev e0183ac）

- **症状**：Firefox（实测 160.0）打开控制台 `http://127.0.0.1:1110/`，点登录返回
  403 `{"error":"仅支持同源控制台请求"}`；Chromium 同页面正常。抓包见 Firefox 的
  登录 POST 带 `Origin: null` + `Sec-Fetch-Site: same-origin`。
- **因果链**（每环都已验证）：
  1. 服务端给所有响应设 `Referrer-Policy: no-referrer`（`cmd/server/main.go:145`）。
  2. 控制台前端用 `fetch(location.origin+'/admin/api/login', {mode:'same-origin', ...})`。
  3. Fetch 规范「append a request Origin header」：referrer policy 为 no-referrer
     且请求模式非 cors 时，`Origin` 序列化为字符串 `"null"`（MDN Origin 文档明确列出）。
     Firefox 实现了这条；Chromium 目前仍发真实 origin——所以只有 Firefox 中招。
  4. `internal/admin/auth.go` 的 `sameOrigin()` 解析 `"null"` 得不到 http/https
     scheme → 403。
- **复现**（对运行中的服务 curl 即可，不需要浏览器）：
  - `-H 'Origin: null'` → 403 仅支持同源控制台请求
  - `-H 'Origin: http://127.0.0.1:<port>'` 或无 Origin → 401 进入密码校验
- **修法**：补丁把响应头改为 `Referrer-Policy: same-origin`。跨站导航仍不带
  Referer（隐私不变），控制台自身的同源 POST 恢复携带真实 Origin。
  **不要改 `sameOrigin()` 放行 `Origin: null`**——那会放松 CSRF 防护，且上游
  `admin_test.go` 明确断言裸 `Origin: null` 必须 403。
- **验证记录**：go1.27.3 下 `go build ./cmd/server` 成功、`go test ./...` 11 包全
  PASS；打补丁二进制起临时实例：响应头变 `same-origin`、正确密码同源登录 200、
  伪造 `Origin: null` 仍 403。

## 何时可以清除该补丁

满足以下**任一**条件即可删除本包（或删掉补丁让本包退化为纯别名），并把
nix-config 的 `modules/nixos/base/custom/ai/meoo2api.nix` 指回 `meoo2api`：

1. **上游修复**：LazyBonesLZY/meoo2api 的 `cmd/server/main.go` 不再对控制台页面
   发送 `Referrer-Policy: no-referrer`（改成 `same-origin`/`strict-origin` 等保留
   同源 Origin 的策略，或按路径区分）。核对方法：
   ```bash
   curl -sI http://127.0.0.1:<port>/ | grep -i referrer-policy
   # 期望不再是 no-referrer；或直接看新 rev 的 cmd/server/main.go
   ```
   基础包 `meoo2api` 由 unstableGitUpdater 跟踪 HEAD，升级后先跑上面的检查再决定。
2. **上游改用兼容实现**：前端 fetch 改为 `mode:'cors'`（CORS 模式下 no-referrer
   不会把 Origin 打成 null），或服务端 `sameOrigin()` 显式接受
   `Origin: null && Sec-Fetch-Site: same-origin` 的组合（需连带其测试一起改，
   属于上游自己的安全决策，本下游不代做）。

**注意**：Chromium 当前发真实 Origin 只是其实现现状，未来若对齐规范也会触发同样
问题——所以「Chromium 能用」不构成删补丁的理由，判据只看上游服务端行为。

补丁失效（上游改了 `main.go` 上下文导致 hunk 失败）时，按根 AGENTS.md
「上游补丁失效时的重新生成方法」对新 rev 重生成，不要手工修上下文。

## 维护约定

- `passthru.updateScript = null`：版本/src 完全跟随基础包，自身不参与 auto-update
  （同 webmux-acp 对 pinnedWebmux 的处理）。基础包升 rev 后本包自动用新源码构建，
  补丁若不适配会在构建期报 hunk 失败——这是有意的闸门，提示维护者按上节判定
  「上游已修（删补丁）」还是「需重生成」。
- `meta.mainProgram` 仍是 `meoo2api`（postInstall 改名逻辑继承自基础包，二进制名
  不变），systemd 模块无需改动即可换用本包。
