{
  lib,
  cmake,
  fetchFromGitHub,
  nix-update-script,
  rustPlatform,
  versionCheckHook,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "anymd";
  version = "8.5.4";

  src = fetchFromGitHub {
    owner = "SylphxAI";
    repo = "anymd";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FO3TvbJiy4EBC0nTp9YY/bHYGEm+xF2AWv+//VxHiVI=";
  };
  __structuredAttrs = true;
  strictDeps = true;

  cargoHash = "sha256-UbC/vAlI/bTkTkWrIY9Iryy9c6dqK3RYPFwa0bYb1pA=";

  nativeBuildInputs = [ cmake ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru = {
    updateScript = nix-update-script { };
    aiProvenance = [
      {
        agent = "dsh";
        involvement = "authored";
      }
    ];
  };

  meta = {
    changelog = "https://github.com/SylphxAI/anymd/blob/v${finalAttrs.version}/CHANGELOG.md";
    description = "Convert any file to clean Markdown for AI agents, as a CLI and MCP server";
    homepage = "https://github.com/SylphxAI/anymd";
    license = lib.licenses.mit;
    mainProgram = "anymd";
    maintainers = import ../maintainers.nix;
  };
})
