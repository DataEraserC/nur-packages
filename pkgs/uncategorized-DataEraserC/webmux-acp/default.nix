{
  fetchFromGitHub,
  webmux,
}:

let
  pinnedWebmux = webmux.override {
    webmuxSource = fetchFromGitHub {
      owner = "mzdluo123";
      repo = "webmux";
      rev = "5512028a55fce892d5ceb40ac2453094ca3a4f51";
      hash = "sha256-jEbTkq2HjEAqqwViPF9oy1QzAD9+V08LNrhTkr+iSUA=";
    };
  };
in
pinnedWebmux.overrideAttrs (old: {
  pname = "webmux-acp";

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    go test -race ./cmd/webmux
    go test -race ./cmd/baseline -skip '^TestFixtureIsolatesAPIGitAndRestoresEnvironment$'
    go test -race ./internal/agentprofile/... ./internal/launch
    go test -race ./internal/service -run '^(TestEnvironmentCapturesOnlySupportedVariables|TestExternalAgentsEnvironmentRoundTripsServiceDefinitions)$' -count=1
    go test -race ./internal/hybrid -run '^TestSelectDeclaredAgentProcess$' -count=20
    go test -race ./internal/hybrid -run '^(TestCheckCreate|TestCodexConnectorMissing|TestCreateACPFailureRemovesSessionAndReturnsStderr|TestStartFailurePreservesCause)$' -count=1
    go test -race ./internal/hybrid -run '^(TestExternalAgentBackgroundCommandLatchesDoneWithoutRefresh|TestTurnWithBackgroundCommandIsDoneOnlyAfterItEnds|TestTurnWithStartedBackgroundCommandIsDoneOnlyAfterItEnds|TestBackgroundWatchStoppedByNewTurnOrSwitch)$' -count=1
    go test -race ./cmd/internal/assemble -run '^TestSessionOptionsUsesInjectedRegistry$'
    go test -race ./internal/api -run '^(TestP2PEndpointsSecurityAndValidation|TestLocalSessionProcessCannotControlP2P|TestP2PRPCAuthAndRouting|TestP2PRPCUsesInjectedRegistryLikeHTTP|TestOneInjectedRegistryServesLaunchAPIAndHybrid)$' -count=1
    go test ./internal/archtest ./internal/docguard
    runHook postCheck
  '';

  passthru = (old.passthru or { }) // {
    updateScript = null;
    inherit webmux;
  };

  meta = (old.meta or { }) // {
    description = "WebMux with support for externally declared ACP agents";
  };
})
