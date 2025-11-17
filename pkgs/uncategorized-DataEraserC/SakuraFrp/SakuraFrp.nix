{
  lib,
  stdenv,
  autoPatchelfHook,
  sources,
  zstd,
  upx,
  ...
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "i686-linux"
    "aarch64-linux"
    "aarch32-linux"
    "mips64-linux"
    "mips-linux"
    "loong64-linux"
  ];
  HostPlatform = stdenv.hostPlatform.system;
  source =
    if lib.elem HostPlatform SupportedPlatforms then
      sources."AAA_netfrp-${HostPlatform}"
    else
      throw "Unsupported platform: ${HostPlatform}";
in
stdenv.mkDerivation {
  inherit (source) version pname src;
  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    upx
    zstd
  ];
  buildInputs = [
  ];
  installPhase = ''
    mkdir -p $out/bin
    install -Dm755 natfrp-service $out/bin/natfrp-service
    install -Dm755 frpc $out/bin/frpc
  '';
  meta = with lib; {
    homepage = "https://www.natfrp.com/";
    mainProgram = "natfrp-service";
    platforms = SupportedPlatforms;
  };
}
