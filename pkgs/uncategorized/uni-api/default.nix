{
  fetchFromGitHub,
  lib,
  nix-update-script,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "uni-api";
  version = "1.7.276-unstable-2026-10-28";
  src = fetchFromGitHub {
    owner = "yym68686";
    repo = "uni-api";
    rev = "4ef15f2b5aad32c02212265f659aefc1f10495a4";
    hash = "sha256-mydOiMD+GvBUHdoitPN3SWIy7cwh1O6aAbSKCnrXdts=";
  };
  __structuredAttrs = true;
  strictDeps = true;
  cargoHash = "sha256-V4XtsaCcP8leEaiXBkfUheAmP9gKj9c7k6PamPLvr68=";

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
