{
  fetchFromGitHub,
  webmux,
}:

let
  version = "0.16.0-unstable-2026-11-15";

  pinnedWebmux = webmux.override {
    webmuxSource = fetchFromGitHub {
      owner = "mzdluo123";
      repo = "webmux";
      rev = "f17eda53cd0f81da6041b88f07624aadaddc415b";
      hash = "sha256-wy7WqoVYObtXSCHa3cCsQGssDkyofomO+GZ/OkQlNW4=";
    };
  };
in
pinnedWebmux.overrideAttrs (old: {
  pname = "webmux-acp";
  inherit version;
  __intentionallyOverridingVersion = true;
  # Overriding webmuxSource alone reuses the base package's vendorHash, which
  # tracks whatever release webmux/ is pinned to. When the main package moves
  # on, that hash no longer matches this older overlay tip and the build fails
  # with a hash mismatch. Pin the hash that belongs to this source.
  vendorHash = "sha256-8jgAcb9znAtAlDfwuBD5+qTimc3mwoCRZ38i6pHr/d4=";
  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

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
