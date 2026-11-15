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
  version = "8.5.9";

  src = fetchFromGitHub {
    owner = "SylphxAI";
    repo = "anymd";
    tag = "v${finalAttrs.version}";
    hash = "sha256-/7Lg8yaH0nmfCzsWCHyz5GhRr8rpZcPbH58oh9Ffcvk=";
  };
  __structuredAttrs = true;
  strictDeps = true;

  cargoHash = "sha256-eQta/I6zboV/p1FFcEo9RGIHk/yREO1fpgSkLuSZYTc=";

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
