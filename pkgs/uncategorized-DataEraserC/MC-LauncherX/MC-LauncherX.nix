{
  lib,
  stdenv,
  fetchurl,
  unzip,
  patchelf,
  makeWrapper,
  icu,
  openssl,
  ...
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];
  HostPlatform = stdenv.hostPlatform.system;

  version =
    {
      x86_64-linux = "18b0ac05-425f-44f9-baec-bb9d07b5371c/net9.0-linux.linux-x64";
      aarch64-linux = "c666177b-870c-420c-8390-c33554084a97/net9.0-linux.linux-arm64";
      x86_64-darwin = "ebd06b07-4cb6-439b-adc4-3b30d9d65930/net9.0-osx.osx-x64";
      aarch64-darwin = "b9eb64ab-2432-4442-b3b2-fb018cc37f61/net9.0-osx.osx-arm64";
    }
    .${HostPlatform} or (throw "Unsupported platform: ${HostPlatform}");

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://api.corona.studio/Build/get/18b0ac05-425f-44f9-baec-bb9d07b5371c/net9.0-linux.linux-x64.zip";
        hash = "sha256-Z/+q3FAxje3nXz7Bxufbx94w/IEN6b1Mq49/ylu2Pks=";
      };
      aarch64-linux = fetchurl {
        url = "https://api.corona.studio/Build/get/c666177b-870c-420c-8390-c33554084a97/net9.0-linux.linux-arm64.zip";
        hash = "sha256-5fxcv+YmzNGzmp4R+zIzhLExrGwgA4rl6AFjsXwytlI=";
      };
      x86_64-darwin = fetchurl {
        url = "https://api.corona.studio/Build/get/ebd06b07-4cb6-439b-adc4-3b30d9d65930/net9.0-osx.osx-x64.zip";
        hash = "sha256-DZ1Sj2m26KihvQ+OKz3kCUgVsv+6rt0jZEdXc5r1tig=";
      };
      aarch64-darwin = fetchurl {
        url = "https://api.corona.studio/Build/get/b9eb64ab-2432-4442-b3b2-fb018cc37f61/net9.0-osx.osx-arm64.zip";
        hash = "sha256-mEGFv4oMy9Zmow3HYD5MsZ7yz48SeYiS66JVxvYqy8U=";
      };
    }
    .${HostPlatform};
in
stdenv.mkDerivation {
  pname = "MC-LauncherX";
  inherit version src;
  sourceRoot = ".";

  passthru.updateScript = [ (toString ./update.sh) ];

  dontStrip = true;

  nativeBuildInputs = [
    unzip
    patchelf
    makeWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
  ];
  installPhase = ''
    mkdir -p $out/bin
    install -Dm755 * $out/bin/
  '';
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    for f in $out/bin/*; do
      [ -x "$f" ] || continue
      patchelf --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" "$f" || true
    done
    for f in $out/bin/*; do
      [ -x "$f" ] || continue
      wrapProgram "$f" --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          icu
          openssl
          stdenv.cc.cc.lib
        ]
      }"
    done
  '';
  meta = with lib; {
    homepage = "https://kb.corona.studio/";
    mainProgram = "LauncherX.Avalonia";
    platforms = SupportedPlatforms;
    broken = true;
  };
}
