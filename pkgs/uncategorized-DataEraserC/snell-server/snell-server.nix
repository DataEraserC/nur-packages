#https://t.me/nixos_zhcn/590791
{
  lib,
  stdenv,
  unzip,
  patchelf,
  glibc,
  gcc,
  sources,
  ...
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "i686-linux"
    "aarch64-linux"
    "aarch32-linux"
  ];
  HostPlatform = stdenv.hostPlatform.system;
  source =
    if lib.elem HostPlatform SupportedPlatforms then
      sources."snell-server-${HostPlatform}"
    else
      throw "Unsupported platform: ${HostPlatform}";
in
stdenv.mkDerivation {
  inherit (source) version pname src;
  nativeBuildInputs = [
    unzip
    patchelf
  ];
  buildInputs = [
    glibc
    gcc.cc.lib
  ];
  unpackPhase = ''
    unzip $src
  '';
  installPhase = ''
    install -Dm755 snell-server $out/bin/snell-server
    patchelf --print-needed $out/bin/snell-server
  '';
  meta = with lib; {
    homepage = "https://nssurge.com";
    mainProgram = "snell-server";
    platforms = SupportedPlatforms;
  };
}
