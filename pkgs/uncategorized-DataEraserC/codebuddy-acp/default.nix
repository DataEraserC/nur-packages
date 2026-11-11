{
  lib,
  buildGoModule,
  codebuddy,
  versionCheckHook,
}:
buildGoModule (finalAttrs: {
  pname = "codebuddy-acp";
  version = "1.0.0";

  __structuredAttrs = true;
  strictDeps = true;

  src = ./.;

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
    "-X main.defaultRealBinary=${lib.getExe codebuddy}"
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    go test -race ./...
    runHook postCheck
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--acp-proxy-version";

  postInstallCheck = ''
    test "$(find $out/bin -mindepth 1 -maxdepth 1 -printf '%f\n')" = codebuddy-acp
    test -f $out/bin/codebuddy-acp
    test ! -L $out/bin/codebuddy-acp
    test ! -e $out/libexec
    test "$(od -An -tx1 -N4 $out/bin/codebuddy-acp | tr -d ' \n')" = 7f454c46
    test "$(env -u CODEBUDDY_ACP_REAL $out/bin/codebuddy-acp --acp-proxy-version)" = ${finalAttrs.version}
    test "$(env -u CODEBUDDY_ACP_REAL $out/bin/codebuddy-acp --version)" = ${codebuddy.version}
  '';

  passthru = {
    inherit codebuddy;
    aiProvenance = [
      {
        agent = "dsh";
        model = "1AgentRouter/gpt-5.6-sol";
        involvement = "assisted";
      }
      {
        agent = "dsh";
        model = "2AgentRouter/gpt-5.6-sol";
        involvement = "assisted";
      }
    ];
  };

  meta = {
    description = "ACP proxy for CodeBuddy that adds the missing session/list capability";
    homepage = "https://github.com/DataEraserC/nur-packages";
    license = lib.licenses.mit;
    mainProgram = "codebuddy-acp";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maintainers = import ../maintainers.nix;
  };
})
