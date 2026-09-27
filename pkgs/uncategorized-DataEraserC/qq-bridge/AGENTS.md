# qq-bridge

## 运行时默认数据目录（`$QQ_BRIDGE_HOME`）

qq-bridge 的运行时数据（`config.json`、`state/` 等）放在一个专用目录，启动脚本里的兜底展开为：

```bash
QQ_BRIDGE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/qq-bridge"
```

（见 `default.nix`；桥接启动时读不到就用这个值。）控制台授权与会话状态都落在该目录。

- 这只是**本包可执行自身**的解析结果；消费端可以经环境变量 override 指到别处。
- 同一次会话里解析出的实际数据目录必须唯一：与 MCP 侧（`qq-bridge-dsh`）的一致性要求见 [`../qq-bridge-dsh/AGENTS.md`](../qq-bridge-dsh/AGENTS.md)。

## 修改默认数据目录的两种方式

1. **运行时环境变量**（优先级最高）：`QQ_BRIDGE_HOME=/custom/path qq-bridge …`，对已构建的包即刻生效。
2. **包 override**（改构建进 wrapper 的默认值）：

   ```nix
   nur-DataEraserC.packages.${pkgs.system}.qq-bridge.override {
     qqBridgeHome = "/custom/path";
   }
   ```

   未 override 时保持动态展开 `${XDG_DATA_HOME:-$HOME/.local/share}/qq-bridge`；override 后 wrapper 直接采用该值作为兜底（路径不要含空格），环境变量仍可在运行时覆盖。该参数同时暴露于 `passthru.qqBridgeHome` 便于检查。

两种方式都要保证 `qq-bridge-dsh` 侧解析到同一目录：MCP 侧有同名 `qqBridgeHome` override 参数，联用时**两侧必须 override 成同一个值**，见 [`../qq-bridge-dsh/AGENTS.md`](../qq-bridge-dsh/AGENTS.md)。
