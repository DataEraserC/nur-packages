{
  fetchFromGitHub,
  webmux,
}:

let
  version = "0.19.1-unstable-2026-11-28";

  pinnedWebmux = webmux.override {
    # The overlay tip is a frozen commit while the base package floats to newer
    # upstream releases, so pin both hashes belonging to this source rather than
    # inherit whatever the base package currently needs.
    webPnpmDepsHash = "sha256-jeufMwHqygtsf2FdXQIN/okE2lyVjS+EjYy+2fxXGv4=";
    webmuxSource = fetchFromGitHub {
      owner = "mzdluo123";
      repo = "webmux";
      rev = "4d3d8c3f4d93824fbbef318ed0b755b98a9611be";
      hash = "sha256-ntQ8e4LQBUO6kX6IryzOn7O0Eiqz/GM+Din461Hkawc=";
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
  vendorHash = "sha256-3DGb4/ib8UVDke83n2lJtmAurgPnRc63gybQv+aWIxc=";
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
    go test -race ./internal/hybrid -run '^TestDeclaredAgentOverForeignSignal$' -count=1
    go test -race ./internal/hybrid -run '^(TestCheckCreate|TestCodexConnectorMissing|TestCreateACPFailureRemovesSessionAndReturnsStderr|TestStartFailurePreservesCause)$' -count=1
    go test -race ./internal/hybrid -run '^(TestTurnWithBackgroundCommandIsDoneOnlyAfterItEnds|TestTurnWithStartedBackgroundCommandIsDoneOnlyAfterItEnds|TestBackgroundWatchStoppedByNewTurnOrSwitch)$' -count=1
    go test -race ./internal/clicmd -run '^TestViewChangeAnswersPausedSwitch$' -count=1
    go test -race ./internal/session -run '^TestAttentionPolicyModesAndSources$' -count=1
    go test -race ./internal/hybrid -run '^(TestTurnUncertain|TestSwitchAwaitingChoice|TestSwitchUnknownTurnState|TestSwitchUnknownTurnStateLegacyClient|TestSwitchChoiceFirstAnswerWins|TestSwitchChoiceRacesIdle)$' -count=1
    go test -race ./downstream -count=1
    go test -race ./cmd/internal/assemble -run '^TestSessionOptionsEmptyAgentSelection$'
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
