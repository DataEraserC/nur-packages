{
  stdenvNoCC,
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  unzip,
  ...
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "i686-linux"
    "aarch64-linux"
    "aarch32-linux"
    "mips-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];
  HostPlatform = stdenv.hostPlatform.system;
  version = "3.3.12";

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://www.cpolar.com/static/downloads/releases/${version}/cpolar-stable-linux-amd64.zip";
        hash = "sha256-89Z28kjg7EYyjeFKKu9EJlsLF5gvn8vwmI4v/DfHikU=";
      };
      i686-linux = fetchurl {
        url = "https://www.cpolar.com/static/downloads/releases/${version}/cpolar-stable-linux-386.zip";
        hash = "sha256-HY8UB0SCi6/2uTr51oZxn2comBq/1l30/pG84ihZGFk=";
      };
      aarch64-linux = fetchurl {
        url = "https://www.cpolar.com/static/downloads/releases/${version}/cpolar-stable-linux-arm64.zip";
        hash = "sha256-uI2nzXHy/MG0GJwaNumoiTQ49eFpF4nAcwPoM2CWf/s=";
      };
      aarch32-linux = fetchurl {
        url = "https://www.cpolar.com/static/downloads/releases/${version}/cpolar-stable-linux-arm.zip";
        hash = "sha256-npqA+rnaSnKPjOnRSsetN8F0uWdSNz9b+BE5F+vmim8=";
      };
      mips-linux = fetchurl {
        url = "https://www.cpolar.com/static/downloads/releases/${version}/cpolar-stable-linux-mips.zip";
        hash = "sha256-Ii+kRQdqr5xKt7QwWeOZaLq+i+DlDng+9lhFcrIAEeU=";
      };
      x86_64-darwin = fetchurl {
        url = "https://www.cpolar.com/static/downloads/releases/${version}/cpolar-stable-darwin-amd64.zip";
        hash = "sha256-S/d1DF24/AO7yruEw06UipacW5VF4yYFFNnTk90LSPI=";
      };
      aarch64-darwin = fetchurl {
        url = "https://www.cpolar.com/static/downloads/releases/${version}/cpolar-stable-darwin-arm64.zip";
        hash = "sha256-hXa4xwsnrMiO4K+lfJeCsBsq0dH7ZU/nK/p4eVbgB44=";
      };
    }
    .${HostPlatform};
in
stdenvNoCC.mkDerivation rec {
  pname = "cpolar";
  inherit version src;

  passthru.updateScript = [ (toString ./update.sh) ];

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
    description = "cpolar (Polar Cloud): Expose local web services to the public internet with ease.";
    mainProgram = "cpolar";
    license = lib.licenses.unfree;
    platforms = SupportedPlatforms;
  };
}
