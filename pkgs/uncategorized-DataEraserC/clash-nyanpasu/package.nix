{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  wrapGAppsHook3,
  autoPatchelfHook,
  clash-meta,
  openssl,
  webkitgtk_4_1,
  udev,
  libayatana-appindicator,
}:
stdenv.mkDerivation rec {
  pname = "clash-nyanpasu";
  version = "1.6.1";

  src = fetchurl {
    url = "https://github.com/keiko233/clash-nyanpasu/releases/download/v${version}/clash-nyanpasu_${version}_amd64.deb";
    hash = "sha256-191Mhq7eYQYNqYO+a4G1sQR/6hG8WcFwLn5AEdNx0j4=";
  };

  nativeBuildInputs = [
    dpkg
    wrapGAppsHook3
    autoPatchelfHook
  ];

  buildInputs = [
    openssl
    webkitgtk_4_1
    stdenv.cc.cc
  ];

  runtimeDependencies = [
    (lib.getLib udev)
    libayatana-appindicator
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mv usr/* $out

    runHook postInstall
  '';

  postFixup = ''
    rm -f $out/bin/clash
    ln -sf ${lib.getExe clash-meta} $out/bin/${clash-meta.meta.mainProgram}
  '';

  meta = {
    description = "Clash GUI based on tauri";
    homepage = "https://github.com/keiko233/clash-nyanpasu";
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.gpl3Plus;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = [ lib.maintainers.Guanran928 ];
    broken = true;
    mainProgram = "clash-nyanpasu";
  };
}
