{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeShellWrapper,
  wrapGAppsHook3,
  python3,
  coreutils,
  bashInteractive,
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
    makeShellWrapper
    wrapGAppsHook3
    python3
  ];

  buildInputs = libraries ++ [
    coreutils
    bashInteractive
  ];

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

    # Patch safe-bin shims: upstream uses #!/bin/bash and /bin/rm which don't
    # exist on NixOS. Fix the shebangs and set the real-rm paths via env vars
    # that safe-delete-common.sh reads (SAFE_DELETE_REAL_*).
    patchShebangs $out/opt/WorkBuddy/resources/app.asar.unpacked/cli/vendor/shim/safe-bin

    # Repack app.asar with the Wayland/waypipe show() fix.
    # WorkBuddy creates BrowserWindow with show:false and only calls show()
    # in the ready-to-show callback. On Wayland/waypipe, ready-to-show never
    # fires because Chromium needs a surface commit to produce the first
    # frame, but the surface isn't shown until show() — a deadlock. The
    # patch adds a show() call at the top of the ready-to-show handler.
    python3 ${./repack-asar.py} \
      $out/opt/WorkBuddy/resources/app.asar \
      $out/opt/WorkBuddy/resources/app.asar.new
    mv $out/opt/WorkBuddy/resources/app.asar.new \
       $out/opt/WorkBuddy/resources/app.asar

    cp -r usr/share/icons $out/share/icons
    install -Dm644 usr/share/applications/workbuddy.desktop \
      $out/share/applications/workbuddy.desktop

    substituteInPlace $out/share/applications/workbuddy.desktop \
      --replace-fail 'Exec=/opt/WorkBuddy/workbuddy' "Exec=$out/bin/workbuddy"

    # makeShellWrapper, not makeWrapper: wrapGAppsHook3 pulls in
    # make-binary-wrapper's setup hook, which redefines makeWrapper to
    # makeBinaryWrapper. The binary implementation bakes --add-flags into a
    # fixed argv array, so the shell conditional below would reach Electron
    # verbatim, unexpanded, and the Wayland flags would never apply.
    # makeShellWrapper keeps the wrapper a bash script, so the condition is
    # evaluated at run time.
    makeShellWrapper $out/opt/WorkBuddy/workbuddy $out/bin/workbuddy \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath libraries}" \
      --set SAFE_DELETE_REAL_RM "${lib.getExe' coreutils "rm"}" \
      --set SAFE_DELETE_REAL_RMDIR "${lib.getExe' coreutils "rmdir"}" \
      --set SAFE_DELETE_REAL_UNLINK "${lib.getExe' coreutils "unlink"}"

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
