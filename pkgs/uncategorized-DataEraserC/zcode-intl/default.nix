{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:
let
  version = "3.16.3";

  plat =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hash =
    {
      x86_64-linux = "sha256-SdAHZHuDHuUiDuNNCX4Dj7iaLfLGhrl6o7awLn0KC6I=";
      aarch64-linux = "sha256-98r+ELzGueqtwV8zHFFJcPhJV/NrNbyV1RmkxiDNyQ4=";
    }
    .${stdenv.hostPlatform.system};

  src = fetchurl {
    url = "https://cdn-zcode.z.ai/zcode/electron/releases/${version}/linux-${plat}/ZCode-${version}-linux-${plat}.AppImage";
    inherit hash;
  };

  contents = appimageTools.extract {
    pname = "zcode-intl";
    inherit version src;
  };
in
appimageTools.wrapType2 {
  pname = "zcode-intl";
  inherit version src;
  __structuredAttrs = true;
  strictDeps = true;

  extraInstallCommands = ''
    install -Dm644 ${contents}/zcode.desktop $out/share/applications/zcode-intl.desktop
    substituteInPlace $out/share/applications/zcode-intl.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=zcode-intl' \
      --replace-fail 'Icon=zcode' 'Icon=zcode-intl'
    install -Dm644 ${contents}/zcode.png $out/share/pixmaps/zcode-intl.png
  '';

  passthru.updateScript = [ (toString ./update.sh) ];

  meta = {
    description = "AI coding workspace by Z.ai with multi-agent development (international edition)";
    homepage = "https://zcode.z.ai/en";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
    mainProgram = "zcode-intl";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
