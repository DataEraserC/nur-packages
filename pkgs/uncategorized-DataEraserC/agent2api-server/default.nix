{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
  makeWrapper,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "agent2api-server";
  version = "3.4.2";

  src = fetchFromGitHub {
    owner = "aimod-cc";
    repo = "Agent2API";
    tag = "v${finalAttrs.version}";
    hash = "sha256-B2YjdzU/cbgli5WFEy4naDJIwipcAg6vsACcaagiBD0=";
  };

  cargoRoot = "desktop-tauri/src-tauri";
  buildAndTestSubdir = "desktop-tauri/src-tauri";

  cargoHash = "sha256-nMIYEUCJJ5ZMyKRDw1YreTIX4Rfi5ysg0cIC6JzAWzA=";

  cargoBuildFlags = [
    "-p"
    "agent2api-server"
  ];
  cargoTestFlags = [
    "-p"
    "agent2api-server"
  ];

  # Upstream v3.4.1 test code predates its own type changes: RequestQuery grew
  # client/api_key/production_only/completed_only, WebDavConfig grew user_agent,
  # and send_with_retry gained the images and network parameters (its telemetry
  # argument is now an Arc). The library and the binary compile; only the test
  # targets fail. One more test still asserts the built-in CodeArts quota
  # classifier, which moved to the out-of-tree agent2api-providers plugin,
  # so adapter_for() now hands out the missing-plugin placeholder. Repair the
  # three call sites and mark that obsolete case #[ignore]; the other 277 tests
  # keep running. Remove the patch once upstream fixes its tests (v3.4.2 and
  # master still carry the old shapes).
  patches = [ ./test-drift.patch ];

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
