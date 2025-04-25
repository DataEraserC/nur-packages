{
  lib,
  stdenv,
  autoPatchelfHook,
  sources,
  unzip,
  ...
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];
  HostPlatform = stdenv.hostPlatform.system;
  source =
    if lib.elem HostPlatform SupportedPlatforms then
      sources."MC-LauncherX-${HostPlatform}"
    else
      throw "Unsupported platform: ${HostPlatform}";
in
stdenv.mkDerivation {
  inherit (source) version pname src;
  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];
  buildInputs = [
    stdenv.cc.cc.lib
  ];
  installPhase = ''
    mkdir -p $out/bin
    install -Dm755 * $out/bin/
  '';
  meta = with lib; {
    homepage = "https://kb.corona.studio/";
    mainProgram = "LauncherX.Avalonia";
    platforms = SupportedPlatforms;
    broken = true;
  };
}
