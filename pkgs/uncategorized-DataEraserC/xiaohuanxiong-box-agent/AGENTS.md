# xiaohuanxiong-box-agent

从桌面 deb 的 `opt/商汤小浣熊/resources/box-agent-runtime` 抽出 Box-Agent ACP 运行时，不打包 Electron，也不依赖桌面 GUI。

- **Nuitka 二进制不能走 `autoPatchelfHook`**：设 `dontStrip = true; dontPatchELF = true;`，只手动 `patchelf --set-interpreter` 加 `--replace-needed libz/libc/libdl/libpthread`；autoPatchelf 会改 RUNPATH，破坏 Nuitka 的自解压。
- **版本与源码继承 `xiaohuanxiong`**：`inherit (xiaohuanxiong) version src;`，桌面升级时跟着走，不单独 pin 版本。
- **initialize 只有 `loadSession` + `resume`，没有 `session/list`**：`session/list` 由 `xiaohuanxiong-acp` 的 Go proxy 补；不要在本包外面再套 wrapper。
- 验证：`printf initialize | box-agent-acp` 应返回 `agentInfo.name = "box-agent"`；把 `BOX_AGENT_HOME` 指到临时目录，避免碰桌面的 `~/.box-agent`。
