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

  # Only the distinctly named shim is installed. Never shadow the real
  # `codebuddy` in the global PATH: a deployment that needs the shim behind a
  # wrapper (e.g. multi-instance) puts it on WebMux's session PATH under the
  # agent's name, isolated to that service. CODEBUDDY_ACP_REAL always points
  # at the real CLI, so the shim works under any name.
  postInstall = ''
    wrapProgram $out/bin/codebuddy-acp \
      --set CODEBUDDY_ACP_REAL ${lib.getExe codebuddy}
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
