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
    rev = "a5b99552ab89db89c5eeecd900a0be65aa33044c";
    hash = "sha256-b3kpzSjgIzDW5HEAwi3aBEfVc8AEqjWFke986kjEJQ0=";
  };
  __structuredAttrs = true;
  strictDeps = true;
  cargoHash = "sha256-FGMBlOOGFHhExOmdxpTy8IkSPCth50GCj2onxoSUlaw=";

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
