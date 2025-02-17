{
  stdenvNoCC,
  autoPatchelfHook,
  sources,
  lib,
  stdenv,
  unzip,
  ...
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "i686-linux"
    "aarch32-linux"
    "mips-linux"
    "aarch64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
  ];
  HostPlatform = stdenv.hostPlatform.system;
  source =
    if lib.elem HostPlatform SupportedPlatforms then
      sources."cpolar-${HostPlatform}"
    else
      throw "Unsupported platform: ${HostPlatform}";
in
stdenvNoCC.mkDerivation rec {
  inherit (source) version pname src;

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
  ];
  buildInputs = [
  ];

  unpackPhase = ''
    unzip $src
  '';

  installPhase = ''
    runHook preInstall
    _install() {
      mkdir -p $out/{bin,cpolar}
      mv cpolar $out/bin/
      chmod +x $out/bin/cpolar
    }
    _install
    runHook postInstall
  '';

  meta = {
    description = "cpolar";
    license = lib.licenses.unfree;
    platforms = SupportedPlatforms;
  };
}
