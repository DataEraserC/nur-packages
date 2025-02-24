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
stdenv.mkDerivation rec {
  inherit (source) version pname src;
  nativeBuildInputs = [
    unzip
    patchelf
  ];
  buildInputs = [
    glibc
    gcc.cc.lib
  ];
  runtimeDependencies = [
    glibc
    gcc.cc.lib
  ];
  runtimeLibraryPath = lib.makeLibraryPath runtimeDependencies;
  unpackPhase = ''
    unzip $src
  '';
  installPhase = ''
    install -Dm755 snell-server $out/bin/snell-server
  '';
  meta = with lib; {
    homepage = "https://nssurge.com";
    mainProgram = "snell-server";
    platforms = platforms.linux;
  };
}
