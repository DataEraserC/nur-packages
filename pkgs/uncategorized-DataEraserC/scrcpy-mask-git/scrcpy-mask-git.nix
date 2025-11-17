{
  lib,
  stdenv,
  rustPlatform,
  cargo-tauri,
  darwin,
  glib-networking,
  libayatana-appindicator,
  nodejs,
  openssl,
  pkg-config,
  pnpm_9,
  webkitgtk_4_1,
  wrapGAppsHook4,
  sources,
}:

rustPlatform.buildRustPackage rec {
  inherit (sources.AAA_scrcpy-mask) pname version src;

  cargoDeps = rustPlatform.importCargoLock {
    lockFile = "${src}/src-tauri/Cargo.lock";
    outputHashes =
      {
      };
  };
  cargoLock.lockFile = "${src}/src-tauri/Cargo.lock";
  cargoRoot = "src-tauri/";

  postPatch = '''';

  pnpmDeps = pnpm_9.fetchDeps {
    inherit
      pname
      version
      src
      ;

    hash = "sha256-spQBFFRX2S0nVTfTjR5zC2Z+7T/IcCCZ9Q0CVlNw/Qo";
  };

  nativeBuildInputs = [
    cargo-tauri.hook

    nodejs
    pkg-config
    pnpm_9.configHook
    wrapGAppsHook4
  ];

  buildInputs =
    [ openssl ]
    ++ lib.optionals stdenv.isLinux [
      glib-networking
      libayatana-appindicator
      webkitgtk_4_1
    ]
    ++ lib.optionals stdenv.isDarwin [
      darwin.apple_sdk.frameworks.WebKit
    ];

  buildAndTestSubdir = "examples/api/src-tauri";
  # This example depends on the actual `api` package to be built in-tree
  preBuild = ''
    pnpm build
  '';

  # No one should be actually running this, so lets save some time
  buildType = "debug";
  doCheck = false;

  meta = {
    description = "scrcpy-mask";
    homepage = "https://github.com/AkiChase/scrcpy-mask";
    mainProgram = "program";
    maintainers = with lib.maintainers; [ ];
    broken = true;
  };
}
