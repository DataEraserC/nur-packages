{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeShellWrapper,
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
  libxcrypt-legacy,
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
  release = lib.importJSON ./release.json;

  source =
    release.${stdenv.hostPlatform.system}
      or (throw "mobileclaw: unsupported system ${stdenv.hostPlatform.system}");

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
    libxcrypt-legacy
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
  pname = "mobileclaw";
  inherit (release) version;

  __structuredAttrs = true;
  strictDeps = true;

  # The object store serves the packages only through short-lived SigV4 URLs, so
  # a direct link cannot be pinned here. The manager endpoint is stable and
  # answers with a 302 to a freshly signed URL, which fetchurl follows; the
  # fixed hash still pins the bytes. `name` keeps the store path readable.
  src = fetchurl {
    inherit (source) url hash;
    name = source.file;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeShellWrapper
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
    cp -r opt/MobileClaw $out/opt/MobileClaw
    chmod +x $out/opt/MobileClaw/mobileclaw-desktop

    cp -r usr/share/icons $out/share/icons
    install -Dm644 usr/share/applications/mobileclaw-desktop.desktop \
      $out/share/applications/mobileclaw-desktop.desktop

    substituteInPlace $out/share/applications/mobileclaw-desktop.desktop \
      --replace-fail 'Exec=/opt/MobileClaw/mobileclaw-desktop' "Exec=$out/bin/mobileclaw"

    # makeShellWrapper, not makeWrapper: wrapGAppsHook3 pulls in
    # make-binary-wrapper's setup hook, which redefines makeWrapper to
    # makeBinaryWrapper. The binary implementation bakes --add-flags into a
    # fixed argv array, so the shell condition below would reach Electron
    # verbatim, unexpanded, and the Wayland flags would never apply.
    makeShellWrapper $out/opt/MobileClaw/mobileclaw-desktop $out/bin/mobileclaw \
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
        model = "deepseek-v4.1-flash";
        involvement = "authored";
      }
    ];
  };

  meta = {
    description = "China Mobile Cloud desktop AI office agent";
    homepage = "https://ecloud.10086.cn/portal/product/hotCase";
    license = lib.licenses.unfree;
    mainProgram = "mobileclaw";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
  };
})
