{
  lib,
  buildGoModule,
  martty,
  versionCheckHook,
  xiaohuanxiong,
  xiaohuanxiong-box-agent,
}:
buildGoModule (finalAttrs: {
  pname = "xiaohuanxiong-acp";
  inherit (xiaohuanxiong) version;

  __structuredAttrs = true;
  strictDeps = true;

  src = ./.;

  vendorHash = "sha256-xGPzODAJOls8RyyYdoEbPqz63i4oex41QsF1HNpmWAc=";

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
    "-X main.defaultBoxAgent=${xiaohuanxiong-box-agent}/libexec/box-agent-runtime/bin/box-agent-acp"
    "-X main.defaultMartty=${lib.getExe martty}"
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    go test -race ./...
    runHook postCheck
  '';

  postInstall = ''
    ln -s xiaohuanxiong-acp $out/bin/xiaohuanxiong-acp-resume
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--acp-proxy-version";

  postInstallCheck = ''
    test "$(find $out/bin -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)" = "$(printf '%s\n' xiaohuanxiong-acp xiaohuanxiong-acp-resume | sort)"
    test -L $out/bin/xiaohuanxiong-acp-resume
    test "$(readlink $out/bin/xiaohuanxiong-acp-resume)" = xiaohuanxiong-acp
    test "$(od -An -tx1 -N4 $out/bin/xiaohuanxiong-acp | tr -d ' \n')" = 7f454c46
    test "$(env -u XIAOHUANXIONG_ACP_REAL -u XIAOHUANXIONG_ACP_MARTTY $out/bin/xiaohuanxiong-acp --version)" = "xiaohuanxiong-acp ${finalAttrs.version}"
  '';

  passthru = {
    inherit martty xiaohuanxiong xiaohuanxiong-box-agent;
  };

  meta = {
    description = "ACP bridge and terminal client for the Raccoon Work agent";
    homepage = "https://xiaohuanxiong.com/";
    license = lib.licenses.mit;
    mainProgram = "xiaohuanxiong-acp";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maintainers = import ../maintainers.nix;
  };
})
