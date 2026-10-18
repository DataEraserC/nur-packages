# anymd 打包经验

- **Rust 工作区含 `vendor/` 目录时照常 `fetchCargoVendor` 即可**：`vendor/pdf-extract`、`vendor/adobe-cmap-parser`、`vendor/oar-ocr-vl` 是 workspace `members`，由 `path` 依赖引用而非 crates.io 源，因此 `cargoHash` 只覆盖真正的 registry 依赖（实测 `sha256-UbC/vAlI/…`），不需要 `cargoPatches` 补丁 lockfile
- **默认 feature 集不含 OCR VLM 引擎，不要开 `ocr-vlm`**：`crates/anymd/Cargo.toml` 的 `default = []`，`ocr-vlm = ["anymd-ocr-vlm/candle"]` 会拉进 candle 全家桶，且 `vendor/oar-ocr-vl/build.rs` 在 `cuda` feature 下要调 `nvcc` 现场编 PTX（沙箱无 CUDA 工具链直接 panic）。默认构建只产出 `anymd` 一个二进制，`anymd-ocr-vlm` 伴生程序由用户跑 `anymd setup ocr` 自行获取，符合上游对「默认构建把引擎留在进程外」的设计
- **`transcribe-cpp-sys` 在构建期编译整棵 vendored ggml C++ 树**（`.cargo/config.toml` 用 `TRANSCRIBE_CMAKE_ARGS` 固定 `GGML_NATIVE=OFF` 与 `TRANSCRIBE_X86_CONSERVATIVE=ON`，保证产物不继承构建机指令集），因此 `nativeBuildInputs` 必须含 `cmake`，且这条路径是 `anymd-formats` 的 `native` feature（默认开启）带进来的，不可用 `--no-default-features` 绕开——那会同时砍掉 tesseract/ffmpeg 集成
- **`tesseract`/`ffmpeg`/`ffprobe` 是运行期 PATH 探测，不写进 buildInputs**：`crates/anymd-formats/src/tool.rs` 的 `find()` 走 `$PATH` 查可执行文件，缺失时对应格式降级为提示文本而不是构建失败；要提供这些能力由用户环境（或 wrapper 追加 PATH）决定，打包时不必也不应硬绑
- **上游测试可全部在沙箱跑通**：`cargoCheckHook` 实测 143+319+142 等 20 个 test target 全绿、0 失败，其中依赖外部语料的 `markdown_corpus` 等以 `ANYMD_CORPUS_DIR` 未设时自动跳过（打印 skip 而非 fail），`worker_lifecycle` 需 `ANYMD_TEST_WORKER_LIFECYCLE=1` + `CI=true` 才实跑，默认只打印提示。故**不要设 `doCheck = false`**
- **`versionCheckHook` 直接可用**：`anymd --version` 输出 `anymd 8.5.4`（`SERVER_VERSION` 取自 `CARGO_PKG_VERSION`），无需 `versionCheckProgramArg`
- **本包归 `pkgs/uncategorized-DataEraserC/`**：上游 SylphxAI 的包不属于 xddxdd 上游集合，按 fork 规则放自有目录，`meta.maintainers` 用 `import ../maintainers.nix`
