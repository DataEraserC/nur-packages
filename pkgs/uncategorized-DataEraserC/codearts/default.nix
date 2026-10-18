{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  bashInteractive,
  coreutils,
  git,
  ripgrep,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
let
  release = builtins.fromJSON (builtins.readFile ./release.json);
  source =
    release.${stdenv.hostPlatform.system}
      or (throw "codearts: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "codearts";
  inherit (release) version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    inherit (source) url hash;
  };

  sourceRoot = ".";

  # Bun-compiled single-file executables keep their payload outside ELF
  # sections; stripping removes it and turns them into the bare Bun CLI.
  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  doInstallCheck = true;
  versionCheckKeepEnvironment = "HOME";

  installPhase = ''
    runHook preInstall

    install -Dm755 agentkernel $out/libexec/codearts/bin/codearts
    install -Dm644 codearts $out/libexec/codearts/codearts
    chmod +x $out/libexec/codearts/codearts
    substituteInPlace $out/libexec/codearts/codearts \
      --replace-fail '#!/usr/bin/env bash' '#!${stdenv.shell}'

    makeWrapper $out/libexec/codearts/codearts $out/bin/codearts \
      --prefix PATH : "${
        lib.makeBinPath [
          bashInteractive
          coreutils
          git
          ripgrep
        ]
      }"

    runHook postInstall
  '';

  passthru = {
    updateScript = [ (toString ./update.sh) ];
    aiProvenance = [
      {
        agent = "dsh";
        model = "deepseek-v4-flash";
        involvement = "authored";
      }
    ];
  };

  meta = {
    description = "Terminal coding agent CLI from Huawei Cloud CodeArts";
    homepage = "https://support.huaweicloud.com/codeartsagent/index.html";
    license = lib.licenses.unfree;
    mainProgram = "codearts";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maintainers = import ../maintainers.nix;
  };
})
