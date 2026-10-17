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
        hash = "sha256-xwWd9835sGrwuRgrvXUX2Xj0dNwLRKhuAffvSpJwQio=";
      };
      i686-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_386.tar.zst";
        hash = "sha256-zI5D5aNlKJMdl9urnBI93bl9oHDMldC3N77r12tTUqg=";
      };
      aarch64-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_arm64.tar.zst";
        hash = "sha256-Mu/zM/qLZjPCFudNUwbHMIM+7O95Ta8StUm4WIR48kM=";
      };
      aarch32-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_armv7.tar.zst";
        hash = "sha256-cVBamfZFJDRr2z5Ro/03Bj1QkbNcTnpdRMMsjgH8tpw=";
      };
      mips64-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_mips64.tar.zst";
        hash = "sha256-HziBCQi3EzUdUi0rhFu3vAfAw8/gPMJE95BhuiGeaKU=";
      };
      mips-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_mips.tar.zst";
        hash = "sha256-rfeq7A+cT2gYdsT8+f+6oOADaYyIRZnr9/itiPH7sGw=";
      };
      loong64-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_loong64.tar.zst";
        hash = "sha256-TL75UbfK/e35eEOno4e2mOMFM7rYMe9L/WzClz3Kc/8=";
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
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 natfrp-service $out/bin/natfrp-service
    install -Dm755 frpc $out/bin/frpc
    runHook postInstall
  '';
  meta = with lib; {
    description = "FRP-based tunnel client for the SakuraFrp service bundling natfrp-service and frpc";
    homepage = "https://www.natfrp.com/";
    license = licenses.unfree;
    maintainers = import ../maintainers.nix;
    mainProgram = "natfrp-service";
    platforms = SupportedPlatforms;
  };
}
