{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:
let
  version = "3.16.2";

  plat =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hash =
    {
      x86_64-linux = "sha256-gj88AkqsU4rIeXYFU5pACwajk+uiUQzBT6pYK5fm/Zg=";
      aarch64-linux = "sha256-ttzTKAAxHmxFtGbVkHFfWJP9YHGTLp1G+Eb6AR+1iUU=";
    }
    .${stdenv.hostPlatform.system};

  src = fetchurl {
    url = "https://cdn-zcode.z.ai/zcode/electron/releases/${version}/linux-${plat}/ZCode-${version}-linux-${plat}.AppImage";
    inherit hash;
  };

  contents = appimageTools.extract {
    pname = "zcode-cn";
    inherit version src;
  };
in
appimageTools.wrapType2 {
  pname = "zcode-cn";
  inherit version src;
  __structuredAttrs = true;
  strictDeps = true;

  extraInstallCommands = ''
    install -Dm644 ${contents}/zcode.desktop $out/share/applications/zcode-cn.desktop
    substituteInPlace $out/share/applications/zcode-cn.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=zcode-cn' \
      --replace-fail 'Icon=zcode' 'Icon=zcode-cn'
    install -Dm644 ${contents}/zcode.png $out/share/pixmaps/zcode-cn.png
  '';

  passthru.updateScript = [ (toString ./update.sh) ];

  meta = {
    description = "AI coding workspace by Z.ai with multi-agent development (China edition)";
    homepage = "https://zcode.z.ai/";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
    mainProgram = "zcode-cn";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
