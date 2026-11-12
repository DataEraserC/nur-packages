{
  fetchFromGitHub,
  webmux,
}:

let
  pinnedWebmux = webmux.override {
    webmuxSource = fetchFromGitHub {
      owner = "mzdluo123";
      repo = "webmux";
      rev = "f0bb66ed27a24d5ee74b2cd3b0dc45e1723e1ba9";
      hash = "sha256-vuPOPvvL8K2NIRuADooaYssQb7QQ/k3NV31whg77jk8=";
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
    go test -race ./internal/clicmd -run '^(TestViewChangePaths|TestViewChoicePending)$' -count=1
    go test -race ./internal/session -run '^TestAttentionPolicyModesAndSources$' -count=1
    go test -race ./internal/hybrid -run '^(TestTUITurnState|TestSwitchUnknownTurnState|TestSwitchUnknownTurnStateLegacyClient|TestSwitchChoiceFirstAnswerWins|TestSwitchChoiceRacesIdle)$' -count=1
    go test -race ./downstream -count=1
    go test -race ./cmd/internal/assemble -run '^TestSessionOptionsUsesInjectedRegistry$'
    go test -race ./internal/api -run '^(TestP2PEndpointsSecurityAndValidation|TestLocalSessionProcessCannotControlP2P|TestP2PRPCAuthAndRouting|TestP2PRPCUsesInjectedRegistryLikeHTTP|TestOneInjectedRegistryServesLaunchAPIAndHybrid|TestViewTurnChoiceCapability)$' -count=1
    go test ./internal/archtest ./internal/docguard
    runHook postCheck
  '';

  passthru = (old.passthru or { }) // {
    updateScript = null;
    inherit webmux;
  };

  meta = (old.meta or { }) // {
    description = "WebMux with audited downstream ACP and hybrid-session fixes";
  };
})
