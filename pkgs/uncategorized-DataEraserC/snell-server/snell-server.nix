#https://t.me/nixos_zhcn/590791
{
  lib,
  stdenv,
  unzip,
  gcc,
  upx,
  autoPatchelfHook,
  fetchurl,
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

  version =
    {
      x86_64-linux = "v6.0.0rc2";
      i686-linux = "v6.0.0rc2";
      aarch64-linux = "v6.0.0rc2";
      aarch32-linux = "v5.0.1";
    }
    .${HostPlatform} or (throw "Unsupported platform: ${HostPlatform}");

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://dl.nssurge.com/snell/snell-server-v6.0.0rc2-linux-amd64.zip";
        hash = "sha256-ipxEY8qHz6Xqo3xq8NN6uT6idaoSORmFuyo3XKOr1/I=";
      };
      i686-linux = fetchurl {
        url = "https://dl.nssurge.com/snell/snell-server-v6.0.0rc2-linux-i386.zip";
        hash = "sha256-ZwYO95rE7wu2TFIDAjlmILOgb49tXOtFC+KD5Pp0kzU=";
      };
      aarch64-linux = fetchurl {
        url = "https://dl.nssurge.com/snell/snell-server-v6.0.0rc2-linux-aarch64.zip";
        hash = "sha256-oLKRXLx33Duvj6Bp50HCCAjYoQw6ipPnCaClgGRcO9c=";
      };
      aarch32-linux = fetchurl {
        url = "https://dl.nssurge.com/snell/snell-server-v5.0.1-linux-armv7l.zip";
        hash = "sha256-FEifPoV1aciDXdNZi36mvKU3HUKQrHzw9sjfszgcH7I=";
      };
    }
    .${HostPlatform};
in
stdenv.mkDerivation {
  pname = "snell-server";
  inherit version src;

  passthru.updateScript = [ (toString ./update.sh) ];

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
    upx -d snell-server || true
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
