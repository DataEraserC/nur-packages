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
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "DataEraserC";
    repo = "video-login";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ZSlAhJDtQ4I+DKtTRqrky+gWm0cil7jKg4MMNqxMmvI=";
  };
  __structuredAttrs = true;
  strictDeps = true;

  cargoHash = "sha256-g6Wvsi4vWUfmbwef2QWuFsa0nEVzgyyqAKihXRWwwrU=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [ openssl ];

  cargoBuildFlags = [ "-p" "vlogin-abi" ];

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
