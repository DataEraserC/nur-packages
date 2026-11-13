{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeShellWrapper,
  bubblewrap,
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
  libuuid,
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
{
  pname,
  version,
  url,
  hash,
  appDir,
  executable,
  desktopName,
  mainProgram,
  description,
  homepage,
  updateScript,
}:
let
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
    libuuid
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
stdenv.mkDerivation {
  inherit pname version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    inherit url hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeShellWrapper
  ];

  buildInputs = libraries;

  # The Electron tree ships musl prebuilds of sharp/canvas next to the glibc
  # ones. They are unused on NixOS, but autoPatchelf cannot resolve their musl
  # libc, so drop them before fixup.
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-*.so.*" ];

  dontConfigure = true;
  dontBuild = true;
  sourceRoot = "debroot";

  unpackPhase = ''
    runHook preUnpack
    # chrome-sandbox is setuid in the deb; the build sandbox cannot preserve
    # that mode, and the launcher uses --no-sandbox anyway.
    mkdir -p debroot
    dpkg-deb --fsys-tarfile "$src" |
      tar -x --no-same-owner --no-same-permissions -C debroot
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share/applications
    cp -r opt/${appDir} $out/opt/${appDir}
    chmod +x $out/opt/${appDir}/${executable}

    find $out/opt/${appDir}/resources/app.asar.unpacked \
      -type d -name '*musl*' -prune -exec rm -rf {} + 2>/dev/null || true

    makeShellWrapper $out/opt/${appDir}/${executable} $out/bin/${mainProgram} \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}" \
      --prefix PATH : "${lib.makeBinPath [ bubblewrap ]}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath libraries}"

    install -Dm644 usr/share/applications/${desktopName} \
      $out/share/applications/${desktopName}
    substituteInPlace $out/share/applications/${desktopName} \
      --replace-fail "Exec=/opt/${appDir}/${executable}" "Exec=${mainProgram}"

    cp -r usr/share/icons $out/share/icons

    runHook postInstall
  '';

  passthru.updateScript = [ (toString updateScript) ];

  meta = {
    inherit description homepage;
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ./maintainers.nix;
    inherit mainProgram;
    platforms = [ "x86_64-linux" ];
  };
}
