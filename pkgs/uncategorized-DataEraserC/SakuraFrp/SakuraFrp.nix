{
  lib,
  stdenv,
  autoPatchelfHook,
  fetchurl,
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
  version = "3.1.8";

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_amd64.tar.zst";
        hash = "sha256-AHFAUqiPHll2osQ3nHA8mF7uWULPKG2rhrtGaLJye3g=";
      };
      i686-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_386.tar.zst";
        hash = "sha256-nv2yUg42n/zUy75WPD1cMJggINRKDZj8DKnoCXtnQ4M=";
      };
      aarch64-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_arm64.tar.zst";
        hash = "sha256-NE+8A6izSnRvGWNerqGOnGlnOzHxMoLeLYw/EfT9nGs=";
      };
      aarch32-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_armv7.tar.zst";
        hash = "sha256-ANa//H2ib9yseKMCwMLLdeK0gD1BQ3YcayPq9C8D9S8=";
      };
      mips64-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_mips64.tar.zst";
        hash = "sha256-wUGReqFq5pSDR5je9y2MP9DykqEnkwcABiyJU7OHudE=";
      };
      mips-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_mips.tar.zst";
        hash = "sha256-pRN/n/ZE5pRGZPl3p8vgPJMUV4807oVjwQHExVYkDYs=";
      };
      loong64-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_loong64.tar.zst";
        hash = "sha256-LRkhqdLysmcmqG2OXpVTf3x5njEVQPTTJFdrEX2cGeE=";
      };
    }
    .${HostPlatform};
in
stdenv.mkDerivation {
  pname = "SakuraFrp";
  inherit version src;
  sourceRoot = ".";

  passthru.updateScript = [ (toString ./update.sh) ];

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
