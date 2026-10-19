{
  fetchFromGitHub,
  lib,
  nix-update-script,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "uni-api";
  version = "1.7.276-unstable-2026-10-19";
  src = fetchFromGitHub {
    owner = "yym68686";
    repo = "uni-api";
    rev = "cc0d4d2a38ecb4a1c82db8eb4e958ca7bd660faa";
    hash = "sha256-RG+QnfWLl1yapJTE3aptsrEn6iaIraWE1EFa1E0/N4o=";
  };
  __structuredAttrs = true;
  strictDeps = true;
  cargoHash = "sha256-IALHtmAxZ9Vmtl/CFnTk4f0NflyKf+u8BngdXLAMaSo=";

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
