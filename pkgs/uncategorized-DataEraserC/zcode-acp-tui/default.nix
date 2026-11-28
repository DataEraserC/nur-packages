# Terminal front end for the native ACP bridge.
#
# Martty is a generic ACP TUI client: it launches this wrapper with --acp,
# which execs zcode-acp-native. Both the WebMux chat side and the terminal UI
# therefore use the same ACP bridge, the same zcode-server and the same
# session store (Start Plan included), instead of the vendor zcode-cli TUI.
{
  lib,
  stdenv,
  makeWrapper,
  martty,
  zcode-acp-native,
}:
stdenv.mkDerivation {
  pname = "zcode-acp-tui";
  version = "0.1.0";

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 ${./zcode-acp-tui.sh} $out/bin/zcode-acp-tui
    wrapProgram $out/bin/zcode-acp-tui \
      --set ZCODE_ACP_NATIVE ${lib.getExe zcode-acp-native} \
      --set ZCODE_ACP_MARTTY ${lib.getExe martty}
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x $out/bin/zcode-acp-tui
    $out/bin/zcode-acp-tui --acp --version | grep -q 'zcode-acp-native'
    runHook postInstallCheck
  '';

  meta = {
    description = "Martty terminal front end for the native ZCode ACP bridge";
    license = lib.licenses.asl20;
    mainProgram = "zcode-acp-tui";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
