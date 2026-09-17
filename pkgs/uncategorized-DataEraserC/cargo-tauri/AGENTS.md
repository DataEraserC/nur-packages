# Tauri 应用的源码构建（`cargo-tauri` helper 及仓库内其它 Tauri 包）

- **Rust 编译期 rustc 栈溢出（`EffectiveVisibilitiesVisitor::update_decl_chain`）**：nixpkgs 锁定的 rustc 比上游 CI 新时，编译含 glob 循环（子模块 `use super::*;` 与 `pub(crate) use 子模块::*;` 互相引用）的大型 Tauri 应用会报 `rustc unexpectedly overflowed its stack`；加大 `RUST_MIN_STACK` 只是拖延，仓库里也没有旧版 rustc（不要为单个包往 flake 加 rust-overlay 输入，迁移时会被覆盖）。出路：改打上游预编译 release（`fetchurl` 指向 release 资源 + `nix-update-script { }`），并设 `sourceProvenance = [ binaryNativeCode ]`。
- **Tauri 从源码构建必须启用 `custom-protocol` feature**：`tauri` 的 build.rs 用 `cargo:dev=!custom-protocol` 决定是否加 `--cfg dev`，不加就会去连 `devUrl`（localhost:1420）而不是内嵌资源。设 `cargoBuildFlags = [ "--features" "tauri/custom-protocol" ]`，并把前端产物放到 `tauri.conf.json` 的 `frontendDist` 目录；可用 `nix log` 里 rustc 是否还带 `--cfg dev` 验证。
