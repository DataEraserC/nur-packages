{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  nix-update-script,
  nodejs_26,
}:
buildGo126Module (finalAttrs: {
  pname = "workbuddy2api-panel";
  version = "1.15.14-panel";

  src = fetchFromGitHub {
    owner = "xu20060420fan-cell";
    repo = "workbuddy2api-trae-qoder-minimax-panel";
    tag = "v${finalAttrs.version}";
    hash = "sha256-u3vaXj9zOiB67C07tFf+bwECt2WonrZ4wjZgZAulB1U=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  vendorHash = "sha256-O4uhfTe6dFBH54oBDVJAjKrLVNbIljgEKlKpjlfxVyc=";

  env.CGO_ENABLED = "0";

  subPackages = [
    "cmd/server"
    "cmd/signin"
    "cmd/login"
    "cmd/credit"
  ];

  ldflags = [
    "-s"
    "-w"
  ];

  nativeCheckInputs = [ nodejs_26 ];
  checkPhase = ''
    runHook preCheck
    go test -skip='TestQoderClaimHistory(StickyClaimed|AuditsAllPhases)' ./...
    runHook postCheck
  '';

  postInstall = ''
    mv $out/bin/server $out/bin/wb2api
    install -Dm644 config.example.json $out/share/doc/workbuddy2api-panel/config.example.json
    install -Dm644 README.md $out/share/doc/workbuddy2api-panel/README.md
    install -Dm644 scripts/probe_active.py $out/share/workbuddy2api-panel/probe_active.py
  '';

  passthru = {
    updateScript = nix-update-script { };
    aiProvenance = [
      {
        agent = "dsh";
        model = "1AgentRouter/gpt-5.6-sol";
        involvement = "assisted";
      }
    ];
  };

  meta = {
    changelog = "https://github.com/xu20060420fan-cell/workbuddy2api-trae-qoder-minimax-panel/releases/tag/v${finalAttrs.version}";
    description = "Multi-provider OpenAI-compatible gateway with account pools, check-ins, and a management panel";
    homepage = "https://github.com/xu20060420fan-cell/workbuddy2api-trae-qoder-minimax-panel";
    license = lib.licenses.mit;
    mainProgram = "wb2api";
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.unix;
  };
})
