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
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxkbfile,
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
  iconName,
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
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxkbfile
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

    mkdir -p $out/opt $out/bin $out/share/applications $out/share/pixmaps
    cp -r usr/share/${appDir} $out/opt/${appDir}
    chmod +x $out/opt/${appDir}/${executable}

    # The deb's desktop entry points at /usr/share/..., and Electron's
    # chrome-sandbox cannot be setuid inside the store, so the launcher
    # supplies --no-sandbox and the same conditional Wayland flags as the
    # other Electron apps in this directory.
    makeShellWrapper $out/opt/${appDir}/${executable} $out/bin/${mainProgram} \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}" \
      --prefix PATH : "${lib.makeBinPath [ bubblewrap ]}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath libraries}"

    install -Dm644 usr/share/applications/${desktopName} \
      $out/share/applications/${desktopName}
    substituteInPlace $out/share/applications/${desktopName} \
      --replace-fail "/usr/share/${appDir}/${executable}" "${mainProgram}"

    install -Dm644 usr/share/pixmaps/${iconName}.png \
      $out/share/pixmaps/${iconName}.png

    if [ -f usr/share/applications/${appDir}-url-handler.desktop ]; then
      install -Dm644 usr/share/applications/${appDir}-url-handler.desktop \
        $out/share/applications/${appDir}-url-handler.desktop
      substituteInPlace $out/share/applications/${appDir}-url-handler.desktop \
        --replace-fail "/usr/share/${appDir}/${executable}" "${mainProgram}"
    fi

    if [ -d usr/share/bash-completion ]; then
      cp -r usr/share/bash-completion $out/share/
    fi

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
