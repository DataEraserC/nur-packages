{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:
let
  version = "3.18.2";

  plat =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hash =
    {
      x86_64-linux = "sha256-9rL7OUE6fv4X470IbH0Gpq3KDf2gmaF5jqizUfC3B0k=";
      aarch64-linux = "sha256-7BlOfm+a43hsTBvP0Ui+Mn7/Sr2ebEHvBgFejOnxg3w=";
    }
    .${stdenv.hostPlatform.system};

  src = fetchurl {
    url = "https://cdn-zcode.z.ai/zcode/electron/releases/${version}/linux-${plat}/ZCode-${version}-linux-${plat}.AppImage";
    inherit hash;
  };

  contents = appimageTools.extract {
    pname = "zcode";
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
    exec "@out@/bin/.zcode-unwrapped" \
      ''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}} \
      "$@"
  '';
in
appimageTools.wrapType2 {
  pname = "zcode";
  inherit version src;
  __structuredAttrs = true;
  strictDeps = true;

  extraInstallCommands = ''
    install -Dm644 ${contents}/zcode.desktop $out/share/applications/zcode.desktop
    substituteInPlace $out/share/applications/zcode.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=zcode'
    install -Dm644 ${contents}/zcode.png $out/share/pixmaps/zcode.png

    mv "$out/bin/zcode" "$out/bin/.zcode-unwrapped"
    printf '%s\n' ${lib.escapeShellArg launcher} > "$out/bin/zcode"
    substituteInPlace "$out/bin/zcode" --replace-fail '@out@' "$out"
    chmod +x "$out/bin/zcode"
  '';

  passthru = {
    updateScript = [ (toString ./update.sh) ];
    contents = contents;
  };

  meta = {
    description = "AI coding workspace by Z.ai with multi-agent development";
    homepage = "https://zcode.z.ai/";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
    mainProgram = "zcode";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
