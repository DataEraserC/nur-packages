{
  lib,
  fetchFromGitHub,
  nix-update-script,
  openssl,
  pkg-config,
  rustPlatform,
  stdenv,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "video-login-abi";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "DataEraserC";
    repo = "video-login";
    tag = "v${finalAttrs.version}";
    hash = "sha256-CUr1Neq2W6Kb6HRDbSdKmgDTMDJHrZdOQurV/0L9HCI=";
  };
  __structuredAttrs = true;
  strictDeps = true;

  # Bumping the workspace version changes this too: cargo vendors the local
  # path crates into the same directory, so they hash into it.
  cargoHash = "sha256-ImNgKvP4JTW+8mb/EXvlsVpzSTEmiYnoqtTb4S1e/TQ=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ];

  cargoBuildFlags = [
    "-p"
    "vlogin-abi"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp target/${stdenv.hostPlatform.rust.rustcTargetSpec}/release/libvlogin.so $out/lib/

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script { };
    aiProvenance = [
      {
        agent = "dsh";
        involvement = "assisted";
      }
    ];
  };

  meta = {
    description = "C ABI shared library for multi-channel video site login";
    homepage = "https://github.com/DataEraserC/video-login";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.unix;
  };
})
