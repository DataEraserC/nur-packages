{
  lib,
  appimageTools,
  fetchurl,
}:
{
  pname,
  version,
  url,
  hash,
  desktopFile,
  iconFile,
  mainProgram,
  xdgDir,
  description,
  homepage,
  updateScript,
}:
let
  src = fetchurl {
    inherit url hash;
  };

  contents = appimageTools.extract {
    inherit pname version src;
  };

  launcher = ''
    #!/bin/sh
    export XDG_CONFIG_HOME="$HOME/.config/${xdgDir}"
    exec "@out@/bin/.${mainProgram}-unwrapped" --no-sandbox \
      ''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}} \
      "$@"
  '';
in
appimageTools.wrapType2 {
  inherit pname version src;
  __structuredAttrs = true;
  strictDeps = true;

  extraInstallCommands = ''
    install -Dm644 ${contents}/${desktopFile} $out/share/applications/${mainProgram}.desktop
    substituteInPlace $out/share/applications/${mainProgram}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${mainProgram}' \
      --replace-fail 'Icon=AutoClaw2' 'Icon=${mainProgram}'
    install -Dm644 ${contents}/${iconFile} $out/share/pixmaps/${mainProgram}.png

    mv "$out/bin/${mainProgram}" "$out/bin/.${mainProgram}-unwrapped"
    printf '%s\n' ${lib.escapeShellArg launcher} >"$out/bin/${mainProgram}"
    substituteInPlace "$out/bin/${mainProgram}" --replace-fail '@out@' "$out"
    chmod +x "$out/bin/${mainProgram}"
  '';

  passthru.updateScript = [ (toString updateScript) ];

  meta = {
    inherit description homepage;
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ./maintainers.nix;
    inherit mainProgram;
    platforms = [ "x86_64-linux" ];
  };
}
