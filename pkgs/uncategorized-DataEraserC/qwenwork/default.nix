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
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxscrnsaver,
  libxt,
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
      or (throw "qwenwork: unsupported system ${stdenv.hostPlatform.system}");

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
    libxt
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
  pname = "qwenwork";
  inherit (release) version;

  __structuredAttrs = true;
  strictDeps = true;

  # 千问办公 serves both debs from fixed "latest" object keys on the asset
  # bucket, so the URL is pinnable and the deb's own control version (read by
  # update.sh) pins the version. `name` keeps the store path readable.
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

  unpackPhase = ''
    runHook preUnpack
    dpkg -x $src .
    runHook postUnpack
  '';

  # The tree carries Bun single-file executables (resources/bin/qoderclicn and
  # the qwenwork CLI helpers, whose JS payload lives outside the ELF sections)
  # alongside Electron's shared-library binaries; stripping the former turns
  # them into bare Bun CLIs, so it is off for the whole tree.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share
    cp -r opt/apps/QwenWorkCN $out/opt/QwenWorkCN
    chmod +x $out/opt/QwenWorkCN/qwen-work-cn \
             $out/opt/QwenWorkCN/chrome_crashpad_handler \
             $out/opt/QwenWorkCN/chrome-sandbox \
             $out/opt/QwenWorkCN/resources/image-runtime/bin/node \
             $out/opt/QwenWorkCN/resources/bin/*

    cp -r usr/share/icons $out/share/icons
    install -Dm644 usr/share/applications/qwen-work-cn.desktop \
      $out/share/applications/qwen-work-cn.desktop

    substituteInPlace $out/share/applications/qwen-work-cn.desktop \
      --replace-fail 'Exec=/opt/apps/QwenWorkCN/qwen-work-cn' "Exec=$out/bin/qwenwork"

    # makeShellWrapper, not makeWrapper: wrapGAppsHook3 pulls in
    # make-binary-wrapper's setup hook, which redefines makeWrapper to
    # makeBinaryWrapper. The binary implementation bakes --add-flags into a
    # fixed argv array, so the shell condition below would reach Electron
    # verbatim, unexpanded, and the Wayland flags would never apply.
    makeShellWrapper $out/opt/QwenWorkCN/qwen-work-cn $out/bin/qwenwork \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath libraries}"

    runHook postInstall
  '';

  passthru = {
    updateScript = [ (toString ./update.sh) ];
    aiProvenance = [
      {
        agent = "zcode";
        model = "glm-5.3-flash";
        involvement = "authored";
      }
    ];
  };

  meta = {
    description = "Alibaba QwenWork (千问办公) desktop AI office assistant";
    homepage = "https://qwenwork.cn";
    license = lib.licenses.unfree;
    mainProgram = "qwenwork";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
  };
})
