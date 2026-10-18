{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxscrnsaver,
  libxtst,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  util-linux,
  xdg-utils,
}:
let
  release = builtins.fromJSON (builtins.readFile ./release.json);
  source =
    release.${stdenv.hostPlatform.system}
      or (throw "workbuddy: unsupported platform ${stdenv.hostPlatform.system}");

  koffiArch = if stdenv.hostPlatform.isx86_64 then "linux_x64" else "linux_arm64";

  libraries = [
    alsa-lib
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxscrnsaver
    libxtst
    mesa
    nspr
    nss
    pango
    systemd
    util-linux
    xdg-utils
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "workbuddy";
  inherit (release) version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = libraries;

  autoPatchelfIgnoreMissingDeps = [ "libc.musl-*.so.*" ];

  unpackPhase = ''
    runHook preUnpack
    dpkg -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share
    cp -r opt/WorkBuddy $out/opt/WorkBuddy
    chmod +x $out/opt/WorkBuddy/workbuddy

    # koffi ships prebuilt bindings for every supported OS; keep the one for
    # this platform only, so autoPatchelf does not trip over foreign libcs.
    find $out/opt/WorkBuddy/resources/app.asar.unpacked/node_modules/koffi/build/koffi \
      -mindepth 1 -maxdepth 1 -type d ! -name '${koffiArch}' -exec rm -rf {} +

    cp -r usr/share/icons $out/share/icons
    install -Dm644 usr/share/applications/workbuddy.desktop \
      $out/share/applications/workbuddy.desktop

    substituteInPlace $out/share/applications/workbuddy.desktop \
      --replace-fail 'Exec=/opt/WorkBuddy/workbuddy' "Exec=$out/bin/workbuddy"

    makeWrapper $out/opt/WorkBuddy/workbuddy $out/bin/workbuddy \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath libraries}"

    runHook postInstall
  '';

  passthru = {
    updateScript = [ (toString ./update.sh) ];
    aiProvenance = [
      {
        agent = "dsh";
        model = "deepseek-v4-flash";
        involvement = "authored";
      }
    ];
  };

  meta = {
    description = "AI agent desktop application for everyday office work";
    homepage = "https://www.workbuddy.cn";
    license = lib.licenses.unfree;
    mainProgram = "workbuddy";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
  };
})
