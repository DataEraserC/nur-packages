{
  webmux,
}:

webmux.overrideAttrs (old: {
  pname = "webmux-acp";

  patches = (old.patches or [ ]) ++ [
    ./patches/external-acp-agents.patch
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    go test -race ./internal/agentprofile/... ./internal/service ./internal/launch
    go test -race ./internal/hybrid -run '^TestSelectDeclaredAgentProcess$' -count=20
    go test -race ./internal/hybrid -run '^(TestCheckCreate|TestCodexConnectorMissing|TestCreateACPFailureRemovesSessionAndReturnsStderr|TestStartFailurePreservesCause)$' -count=1
    go test -race ./cmd/internal/assemble -run '^TestSessionOptionsUsesInjectedRegistry$'
    go test -race ./internal/api -run '^TestOneInjectedRegistryServesLaunchAPIAndHybrid$'
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
