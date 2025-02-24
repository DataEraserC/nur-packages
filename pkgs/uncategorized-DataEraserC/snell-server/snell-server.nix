#https://t.me/nixos_zhcn/590791
{
  lib,
  stdenv,
  unzip,
  patchelf,
  glibc,
  gcc,
  upx,
  autoPatchelfHook,
  sources,
  ...
}: let
  SupportedPlatforms = [
    "x86_64-linux"
    "i686-linux"
    "aarch64-linux"
    "aarch32-linux"
  ];
  HostPlatform = stdenv.hostPlatform.system;
  source =
    if lib.elem HostPlatform SupportedPlatforms
    then sources."snell-server-${HostPlatform}"
    else throw "Unsupported platform: ${HostPlatform}";
in
  stdenv.mkDerivation {
    inherit (source) version pname src;
    nativeBuildInputs = [
      unzip
      upx
      autoPatchelfHook
    ];
    buildInputs = [
      gcc.cc.lib
    ];
    unpackPhase = ''
      unzip $src
      upx -d snell-server
    '';
    installPhase = ''
      install -Dm755 snell-server $out/bin/snell-server
    '';
    meta = with lib; {
      homepage = "https://nssurge.com";
      mainProgram = "snell-server";
      platforms = SupportedPlatforms;
    };
  }
