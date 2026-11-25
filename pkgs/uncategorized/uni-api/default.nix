{
  fetchFromGitHub,
  lib,
  nix-update-script,
  pkg-config,
  rustPlatform,
  sqlite,
  zstd,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "uni-api";
  version = "1.7.276-unstable-2026-11-24";
  src = fetchFromGitHub {
    owner = "yym68686";
    repo = "uni-api";
    rev = "222519ef434b3fbc1c9aedc6f423f94a5fb436e0";
    hash = "sha256-X6PuT6WlI39dLBuP09ZNDnOp5JQ49h0rAuaYtk1QhNw=";
  };
  __structuredAttrs = true;
  strictDeps = true;
  cargoHash = "sha256-5zNRFuoKRavnBzUBCbJAg1mrooh2gDrFxX9S295Zm0o=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    sqlite
    zstd
  ];

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version"
      "branch"
    ];
  };
  meta = {
    maintainers = with lib.maintainers; [ xddxdd ];
    description = "Unifies the management of LLM APIs across multiple backend services";
    homepage = "https://github.com/yym68686/uni-api";
    license = lib.licenses.unfree;
    mainProgram = "uni-api-front";
  };
})
