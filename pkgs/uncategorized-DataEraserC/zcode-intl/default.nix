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

  # ZCode is a VS Code fork, but its AppImage launcher passes none of the
  # Wayland arguments that buildVscode (and therefore Trae) adds, and that
  # workbuddy and lobsterai add in their wrappers. A second wrapper here keeps
  # every Electron app in this directory on the same backend with the same IME
  # behaviour. The block expands only when both NIXOS_OZONE_WL and
  # WAYLAND_DISPLAY are set, so an X11 session is untouched.
  launcher = ''
    #!/bin/sh
    exec "@out@/bin/.zcode-intl-unwrapped" \
      ''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}} \
      "$@"
  '';
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

    mv "$out/bin/zcode-intl" "$out/bin/.zcode-intl-unwrapped"
    printf '%s\n' ${lib.escapeShellArg launcher} > "$out/bin/zcode-intl"
    substituteInPlace "$out/bin/zcode-intl" --replace-fail '@out@' "$out"
    chmod +x "$out/bin/zcode-intl"
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
