{
  lib,
  stdenv,
  fetchurl,
  unzip,
  patchelf,
  makeWrapper,
  icu,
  openssl,
  fontconfig,
  libx11,
  libxext,
  libxrender,
  libxi,
  libxcb,
  libxrandr,
  libxcursor,
  libxfixes,
  libxtst,
  libice,
  libsm,
  libxinerama,
  libxscrnsaver,
  libxcomposite,
  libxdamage,
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
      x86_64-linux = "68817072-c920-4868-96b2-3267c2db89cd/net10.0-linux.linux-x64";
      aarch64-linux = "de5a3df4-d51e-4156-92cc-07028c4ea4f3/net10.0-linux.linux-arm64";
      x86_64-darwin = "b8cb35df-de1c-45e1-9eb0-2775a3ad0aab/net10.0-osx.osx-x64";
      aarch64-darwin = "7e63b58f-6413-4c0a-a279-0e4cffc97db2/net10.0-osx.osx-arm64";
    }
    .${HostPlatform} or (throw "Unsupported platform: ${HostPlatform}");

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://api.corona.studio/Build/get/68817072-c920-4868-96b2-3267c2db89cd/net10.0-linux.linux-x64.zip";
        hash = "sha256-s5TYUAO4l+2eQXkzIDvheAIL67pt4K83RXPfoHIGYyk=";
      };
      aarch64-linux = fetchurl {
        url = "https://api.corona.studio/Build/get/de5a3df4-d51e-4156-92cc-07028c4ea4f3/net10.0-linux.linux-arm64.zip";
        hash = "sha256-AcUprG0X+5q7YcU43o7LMlN0nS2jzf/SHe/tnCNj2a8=";
      };
      x86_64-darwin = fetchurl {
        url = "https://api.corona.studio/Build/get/b8cb35df-de1c-45e1-9eb0-2775a3ad0aab/net10.0-osx.osx-x64.zip";
        hash = "sha256-GlBknz2kvKRdMF2EwtIZsKuYXoR3+AUsy0REBoPlevU=";
      };
      aarch64-darwin = fetchurl {
        url = "https://api.corona.studio/Build/get/7e63b58f-6413-4c0a-a279-0e4cffc97db2/net10.0-osx.osx-arm64.zip";
        hash = "sha256-JADV46lgvGOFqqfEX0FO9nOwrUbECEFGWWH2pBd9u9M=";
      };
    }
    .${HostPlatform};

  skiaNupkg = fetchurl {
    url = "https://www.nuget.org/api/v2/package/SkiaSharp.NativeAssets.Linux/2.88.9";
    hash = "sha256-mQ/oBaqRR71WfS66mJCvcc3uKW7CNEHoPN2JilDbw/A=";
  };
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
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 * $out/bin/
    unzip -jo ${skiaNupkg} 'runtimes/linux-x64/native/libSkiaSharp.so' -d $out/bin
    runHook postInstall
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
          fontconfig
          stdenv.cc.cc.lib
          libx11
          libxext
          libxrender
          libxi
          libxcb
          libxrandr
          libxcursor
          libxfixes
          libxtst
          libice
          libsm
          libxinerama
          libxscrnsaver
          libxcomposite
          libxdamage
        ]
      }"
    done
  '';
  meta = with lib; {
    description = "Next-generation Minecraft launcher with a modern Avalonia interface";
    homepage = "https://kb.corona.studio/";
    license = licenses.unfree;
    maintainers = import ../maintainers.nix;
    mainProgram = "LauncherX.Avalonia";
    platforms = SupportedPlatforms;
  };
}
