{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook3,
  coreutils,
  cliproxyapi,
  atk,
  cairo,
  dbus,
  gdk-pixbuf,
  glib,
  glib-networking,
  gtk3,
  libayatana-appindicator,
  librsvg,
  libsoup_3,
  openssl,
  pango,
  webkitgtk_4_1,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "easy-cliproxyapi-bin";
  version = "0.3.111";
  src = fetchurl {
    url = "https://github.com/router-for-me/EasyCLIProxyAPI/releases/download/v${finalAttrs.version}/EasyCLIProxyAPI-v${finalAttrs.version}-Linux-amd64.tar.gz";
    hash = "sha256-dxdZrfK/71AFDT1toswqvRpeUzdSZTetPnPzxhWYuRY=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    atk
    cairo
    dbus
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    libayatana-appindicator
    librsvg
    libsoup_3
    openssl
    pango
    webkitgtk_4_1
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec/easy-cliproxyapi
    install -m644 EasyCLIProxyAPI $out/libexec/easy-cliproxyapi/
    install -m644 ${cliproxyapi.src}/config.example.yaml $out/libexec/easy-cliproxyapi/

    install -Dm755 ${./wrapper.sh} $out/bin/EasyCLIProxyAPI
    substituteInPlace $out/bin/EasyCLIProxyAPI \
      --replace-fail '@out@' "$out" \
      --replace-fail '@coreutils@' '${coreutils}' \
      --replace-fail '@core@' '${cliproxyapi}' \
      --replace-fail '@coreversion@' 'v${cliproxyapi.version}'

    runHook postInstall
  '';

  # The release entry goes live minutes before its assets finish uploading, so
  # nix-update (which trusts releases.atom and prefetches immediately) rewrites
  # `version` and then dies on a 404, leaving a stale hash behind; update.sh
  # waits for the asset itself and writes both fields only once it answers.
  passthru.updateScript = [ (toString ./update.sh) ];

  meta = {
    description = "Desktop GUI for CLIProxyAPI that configures popular AI agents";
    homepage = "https://github.com/router-for-me/EasyCLIProxyAPI";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    platforms = [ "x86_64-linux" ];
    mainProgram = "EasyCLIProxyAPI";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
