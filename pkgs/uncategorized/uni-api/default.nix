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
  version = "1.7.276-unstable-2026-11-22";
  src = fetchFromGitHub {
    owner = "yym68686";
    repo = "uni-api";
    rev = "6981b6be6ba7986427f08fe0f48606031285c167";
    hash = "sha256-fvF7L7LClioD4izFGrILbMsnfP8RxEO/u3Ri14LPiDY=";
  };
  __structuredAttrs = true;
  strictDeps = true;
  cargoHash = "sha256-8rFPe8x37d+CBQR1NANPnEPSA+Y+JQbNqJ07LbnOrAc=";

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
