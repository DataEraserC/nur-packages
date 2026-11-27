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
  version = "1.7.276-unstable-2026-11-26";
  src = fetchFromGitHub {
    owner = "yym68686";
    repo = "uni-api";
    rev = "3f8e8a51a0508205021ec8ce6fd32d8b3dd358d1";
    hash = "sha256-dB4VmGrFio0SsmxnRBkb16AYwzkfPBDgS0ksC745uFE=";
  };
  __structuredAttrs = true;
  strictDeps = true;
  cargoHash = "sha256-PMNlGaOE5neSQKcfLVE1yY9OxSw75rn/DA7Y6YQQt24=";

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
