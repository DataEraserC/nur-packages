# c001apk（Flutter 酷安客户端）打包经验

上游 <https://github.com/TG-Twilight/c001apk>，Linux 桌面端用 nixpkgs `flutter347.buildFlutterApplication`。

## 上游分支差异：固定 tag，不要跟 HEAD

- `main`（HEAD）与最近 tag `1.3.5-release` **不是同一份代码**，且两边 `apps/flutter/pubspec.yaml` 的
  `version:` 都写 `1.3.5+20261023`，版本号完全无法区分，只能靠 commit 固定。
- `1.3.5-release`（`fb3e06c`）把 `main`（`f2a628c`）里的数字联盟自动取号功能**整块删除**（22 文件、1032 行：
  `lib/utils/szlm_duid_client.dart`、`lib/logic/szlm_identity_service.dart` 及 `main.dart`/`request.dart` 三处调用）。
  `main` 上会向第三方 `auni.telecome.cn` 注册一个 DUID（79 字段硬编码合成模板，无账号/token，属协议仿真）。
- 因此本包 **只跟 `<version>-release` tag**：既是上游的稳定发布点，也避开了首个启动就联络第三方的那条路径。
  `update.sh` 用 `ls-remote --tags --refs` + `sed 's#.*refs/tags/\([0-9.]*\)-release$#\1#p'` + `sort -V` 取最新 tag。

## 必须打的补丁：GTK runner 的图标是相对路径

- `linux/my_application.cc` 里 `gtk_window_set_icon_from_file(window, "assets/icon/icon.png", NULL)` 用**相对 CWD**
  的路径，Nix 安装树里永远不存在该文件，运行期静默报 `Error loading icon from file 'assets/icon/icon.png'`
  （窗口照常出图，只是图标丢）。`postPatch` 用 `substituteInPlace` 把它替换成
  `${placeholder "out"}/share/icons/hicolor/256x256/apps/<pname>.png`，`placeholder "out"` 让路径在求值期就绑定到
  最终输出（`makeWrapperArgs`/构建期 `$out` 都不行）。构建后用
  `strings $out/app/c001apk/c001apk | grep share/icons` 复核路径已烘进二进制。

## 依赖与构建

- `pubspec.lock` 有 191 个包：185 hosted + 5 sdk + 1 `path:`（`flutter_inappwebview_android` →
  `third_party/flutter_inappwebview_android`）。`path` 依赖要求 `third_party/` 随源码树一起进 store，
  pub 缓存里没有，别试图改成 hosted 版本（AGP 9 下上游 1.1.3 的 ProGuard 默认文件名已被删除，构建会失败）。
- `pubspec.yaml` 要求 `flutter: '>=3.47.7'`，本仓库 nixpkgs 只有 `flutter = 3.47.4`；实测 3.47.4 构建与运行均正常
  （Flutter 的 SDK 约束只是警告级，`buildFlutterApplication` 不会因它中止），不要为此升级整个 nixpkgs。
- 锁文件用 `pubspec.lock.json`（`lib.importJSON`）+ `update.sh` 里用 python/pyyaml 转换（`yq` 会对这类 lockfile
  输出重复 JSON 键）。
- Linux 端不需要 Android 工具链：`compileSdk 37` / AGP 9.3.3 / keystore 硬闸门（`android/app/build.gradle` 的
  `preBuild` throw）统统不参与桌面构建。WebView 功能在 Linux 上按设计不可用（`Utils.isSupportWebview()` 排除 Linux），
  也无 WebKit 依赖。

## 审计结论（2026-10-28）

静态审计（全树 + CI + vendored 插件 + assets）结论为**无恶意行为**：无 `dart:ffi`/`Process.*`/`Isolate.spawnUri`/`eval`，
无下载后执行的代码；自更新只 GET `api.github.com` 并严格校验 `github.com/TG-Twilight/c001apk` 前缀，最终交给系统浏览器，
不下载不安装；vendored 插件与 pub.dev 1.1.3 归档逐字节相同（仅两处 ProGuard 文件名替换）。隐私面上的既存项（仅在
`main` 或 Android 侧）：`QUERY_ALL_PACKAGES` + 应用列表上传、release 信任用户 CA、Hive 明文存 token、无 `allowBackup=false`；
均属上游行为、不影响 Linux 桌面产物。完整报告见仓库外 `.audit/AUDIT-c001apk.md`（不随仓库提交）。
