# magpie, the desktop build: the signed release binary, wrapped for NixOS.
#
# magpie's GUI links WebKitGTK 4.1 and reads its plugins from
# ~/.config/magpie/plugins; the plugins are Bun packages installed at runtime,
# so the wrapper points MAGPIE_BUN at nixpkgs' Bun (the Bun magpie would
# download itself is built against another glibc and cannot start here).
# MAGPIE_EXECUTABLE names the wrapper, so the autostart and desktop entries
# magpie writes point at the profile's stable path and not at a store path
# that a garbage collection can empty.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  gtk3,
  webkitgtk_4_1,
  libsoup_3,
  glib,
  glib-networking,
  gdk-pixbuf,
  fontconfig,
  libX11,
  wayland,
  xdg-utils,
  bun,
}:
let
  sources = import ./sources.nix;
  inherit (stdenv.hostPlatform) system;
  arch =
    {
      x86_64-linux = "linux-amd64";
      aarch64-linux = "linux-arm64";
    }
    .${system} or (throw "magpie: no release build for ${system}");
  asset = "magpie-${arch}";
in
stdenv.mkDerivation {
  pname = "magpie";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/yetone/magpie-releases/releases/download/v${sources.version}/${asset}";
    sha256 = sources.assets.${asset};
  };

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    webkitgtk_4_1
    libsoup_3
    glib
    glib-networking
    gdk-pixbuf
    fontconfig
    libX11
    wayland
  ];

  installPhase = ''
    runHook preInstall

    # Keep the program's name: WebKit's data folder and the window class
    # follow it.
    install -Dm755 $src $out/libexec/magpie/magpie
    install -Dm644 ${./magpie.svg} $out/share/icons/hicolor/scalable/apps/magpie.svg

    install -d $out/share/applications
    cat > $out/share/applications/magpie.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=magpie
    Comment=Pick the model each AI coding agent on your machine uses
    Exec=$out/bin/magpie %u
    Icon=magpie
    StartupWMClass=magpie
    Categories=Development;Utility;
    MimeType=x-scheme-handler/magpie;
    Terminal=false
    EOF

    runHook postInstall
  '';

  dontWrapGApps = true;

  postFixup = ''
    makeWrapper $out/libexec/magpie/magpie $out/bin/magpie \
      "''${gappsWrapperArgs[@]}" \
      --set MAGPIE_EXECUTABLE $out/bin/magpie \
      --set-default MAGPIE_BUN ${lib.getExe bun} \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]}
  '';

  meta = {
    description = "Pick the model each AI coding agent on your machine uses";
    homepage = "https://usemagpie.ai/";
    downloadPage = "https://github.com/yetone/magpie-releases/releases";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    maintainers = import ../maintainers.nix;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
