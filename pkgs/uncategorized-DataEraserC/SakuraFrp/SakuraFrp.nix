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
  version = "3.1.9";

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_amd64.tar.zst";
        hash = "sha256-QxMKIGbDe2NkWXhe0zIV4r+0r2tfdIDC+weeJmeguKw=";
      };
      i686-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_386.tar.zst";
        hash = "sha256-fJeDAwQCBa9TUPhgnCz2W034nVuK1bxJDIBkgQJdCKA=";
      };
      aarch64-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_arm64.tar.zst";
        hash = "sha256-rlxUfVZIjPfj3zFcxfFdc9nSfhyko7jdoP5lo49BlIw=";
      };
      aarch32-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_armv7.tar.zst";
        hash = "sha256-VGLjcmTBFkicrpMXPjC4PLJ+Ufztx9Pr1sAc3bz5WsA=";
      };
      mips64-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_mips64.tar.zst";
        hash = "sha256-qj0IEiBCvPTa+Vmfocz2a0ywKR+s6kROBdMGD+mKlf4=";
      };
      mips-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_mips.tar.zst";
        hash = "sha256-3LUZ7Ot1YI8BGvlJz5a2W+xWfhCVtHr5KSPWgnnf69U=";
      };
      loong64-linux = fetchurl {
        url = "https://nya.globalslb.net/natfrp/client/launcher-unix/${version}/natfrp-service_linux_loong64.tar.zst";
        hash = "sha256-WwPSUGvegDMB3QyXLD85DIXfDmNgL1DsAMHIOchYXI8=";
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
