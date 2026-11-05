{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
  makeWrapper,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "agent2api-server";
  version = "3.4.1";

  src = fetchFromGitHub {
    owner = "aimod-cc";
    repo = "Agent2API";
    tag = "v${finalAttrs.version}";
    hash = "sha256-17xzNr7PaoOlOFlBmtvJPt5VwUl9BYLYmSmP8eD624A=";
  };

  cargoRoot = "desktop-tauri/src-tauri";
  buildAndTestSubdir = "desktop-tauri/src-tauri";

  cargoHash = "sha256-hVjhaBxsdj6tkLH+aW07P1SHBWoqZpp5br3zpuvigZk=";

  cargoBuildFlags = [
    "-p"
    "agent2api-server"
  ];
  cargoTestFlags = [
    "-p"
    "agent2api-server"
  ];

  nativeBuildInputs = [ makeWrapper ];

  preCheck = ''
    export HOME=$(mktemp -d)
  '';

  postInstall = ''
    mkdir -p $out/share/agent2api
    cp -r ${finalAttrs.src}/desktop-tauri/ui $out/share/agent2api/ui

    mkdir -p $out/libexec
    mv $out/bin/agent2api-server $out/libexec/agent2api-server

    makeWrapper $out/libexec/agent2api-server $out/bin/agent2api-server \
      --set-default AGENT2API_UI_DIR $out/share/agent2api/ui
  '';

  passthru = {
    updateScript = nix-update-script { };
    aiProvenance = [
      {
        agent = "workbuddy";
        model = "deepseek-v4.1-flash";
        involvement = "authored";
      }
    ];
  };

  meta = {
    changelog = "https://github.com/aimod-cc/Agent2API/releases/tag/v${finalAttrs.version}";
    description = "Headless gateway that exposes multi-provider AI client logins as OpenAI-compatible APIs";
    homepage = "https://github.com/aimod-cc/Agent2API";
    license = lib.licenses.unfree;
    mainProgram = "agent2api-server";
    maintainers = import ../maintainers.nix;
  };
})
