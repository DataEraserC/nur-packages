{
  lib,
  buildGoModule,
  codebuddy,
  makeWrapper,
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
  ];

  nativeBuildInputs = [ makeWrapper ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--acp-proxy-version";

  postInstall = ''
    mkdir -p $out/libexec
    ln -s ${lib.getExe codebuddy} $out/libexec/codebuddy
    cp $out/bin/codebuddy-acp $out/bin/codebuddy
    for prog in codebuddy codebuddy-acp; do
      wrapProgram $out/bin/$prog \
        --set CODEBUDDY_ACP_REAL $out/libexec/codebuddy
    done
  '';

  passthru = {
    inherit codebuddy;
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
