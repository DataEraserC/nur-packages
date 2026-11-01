# agent2api 打包笔记

上游：<https://github.com/aimod-cc/Agent2API>（LICENSE 正文是 MIT，末尾另附
「使用声明」第 3 条禁止商业用途与二次分发牟利，因此不是纯 MIT，
`license = lib.licenses.unfree`；仓库 flake 的 `allowUnfree` 默认开启）。

## 两种形态 = 两个包，不是多输出

上游把网关拆成了独立 crate（`desktop-tauri/src-tauri/server/`），两种发布形态
链接同一个 lib，但**产物不同**：

- `agent2api-server`：headless 二进制，无 GUI 依赖。Dockerfile 与 CI 的
  `linux-server` job 出的就是它（可执行文件 + `ui/` 目录，容器内一键更新
  下载的也是这个包）。服务形态，配 `services.dataEraserc.agent2api`。
- `agent2api-desktop`：Tauri 2 壳，进程内跑同一个 server lib，多一整套
  webkit2gtk / gtk3 / appindicator 依赖。

所以是两个衍生而不是一个多输出衍生：桌面端的依赖树与服务端毫无交集，
合并进同一个 drv 只会让服务端也背上 webkit。

## 一棵源码树，cargo workspace 根在子目录

仓库根的 `package.json` 没有任何依赖（只有 `tauri:*` 脚本转发），Rust
workspace 根是 `desktop-tauri/src-tauri/Cargo.toml` —— 它同时是 package 和
workspace root（`members = ["server"]`）。因此两个包都写：

```
cargoRoot = "desktop-tauri/src-tauri";
buildAndTestSubdir = "desktop-tauri/src-tauri";
```

`cargoRoot` 是给 `fetchCargoVendor` 与 `cargoSetupPostPatchHook` 找
`Cargo.lock` 用的，`buildAndTestSubdir` 才是让 cargo 在子目录里跑的（两者
不叠加：hook 只用后者 `cd`，前者只影响取锁文件的位置）。两个包的
`cargoHash` 相同——同一份锁、同一份 vendor 输出。

服务包必须用 `cargoBuildFlags` / `cargoTestFlags` 限定 `-p agent2api-server`：
在 workspace 根直接 `cargo build` 编的是 root package（桌面端），
拉进 tauri + webkit2gtk 那棵树，服务包就不再是无 GUI 依赖的形态了。

## 沙箱里跑测试必须先给一个可写 HOME

凭证加密密钥写在 `paths::config_dir()`（`$HOME/.agent2api`，仅当
`AGENT2API_PROXY_HOME` 未设时），沙箱的 HOME 是 `/homeless-shelter`，
`Db::open` 自己用的是 `std::env::temp_dir()` 所以库能建起来，但加密密钥那步
直接 `Permission denied (os error 13)` → 51 个账号相关用例全挂。修法是
`preCheck = ''export HOME=$(mktemp -d)''`：用例的库按 `temp_dir()+pid+序号`
隔离，共用一份 HOME 不会互相污染。**不要**因此关掉 `doCheck`——除这些之外
534 个用例是过的，且它们真的在跑路由与转发逻辑。

## UI 目录两份，取值方式完全不同

同一份 `desktop-tauri/ui/`（纯静态 JS，无构建步骤，不需要 npm）：

- 服务端：默认取可执行文件同级的 `ui/`，所以装到 `$out/share/agent2api/ui`，
  再把二进制移进 `$out/libexec` 并用 `makeWrapper --set-default
  AGENT2API_UI_DIR ...` 包一层——`--set-default` 保留用户覆盖能力。不移动
  二进制的话默认路径会变成 `$out/bin/ui`，`bin/` 里塞一堆静态资源很难看。
- 桌面端：`path().resource_dir()` 在 Linux 上是 `exe/../lib/<productName>`
  （productName 来自 `tauri.conf.json` = `Agent2API`），而
  `bundle.resources = ["../ui"]` 里越出应用目录的 `..` 段会被打包器映射成
  `_up_`（见 tauri-utils `resources.rs`），所以落地路径是
  `$out/lib/Agent2API/_up_/ui`。上游 `backend.rs::resolve_ui_dir` 同时试
  `<resource>/_up_/ui` 与 `<resource>/ui`，只装前者即可。

## 托盘库是 dlopen 的，rpath 帮不上

`libappindicator-sys` 运行期 `dlopen("libayatana-appindicator3.so.1")`，
没有任何 DT_NEEDED 引用它，`wrapGAppsHook3` 补的 rpath 覆盖不到；缺了就在
启动第一秒 panic（`Failed to load ayatana-appindicator3 or appindicator3
dynamic library`）。必须显式

```
makeWrapperArgs = [ "--prefix" "LD_LIBRARY_PATH" ":" (lib.makeLibraryPath [ libayatana-appindicator ]) ];
```

## 桌面端只能源码构建

`bundle.targets` 只有 `nsis`，CI 只出 macOS dmg / Windows nsis / Linux 的
**服务端** tarball —— Linux 桌面端没有任何 release asset 可用，只能从源码编
（一条 40 分钟的 tauri 构建）。`cargoInstallHook` 还会把 workspace 的
`libworkbuddy_proxy_desktop_lib.{so,a}`（`crate-type` 里的 cdylib/staticlib）
拷进 `$out/lib`，`postInstall` 里删掉，只留 `lib/Agent2API`。

二进制名是 cargo package 名 `workbuddy-proxy-desktop`，`mainBinaryName` 只影响
tauri 打包器；`postInstall` 里 `mv` 成 `agent2api`（必须在 `postInstall` 做，
`postFixup` 时 wrapGAppsHook 已经按旧名字包好了）。
