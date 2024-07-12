{
  fetchurl,
  lib,
  stdenv,
  pkgs,
  appimage-run,
  makeDesktopItem,
}:
stdenv.mkDerivation rec {
  pname = "escrcpy";
  version = "1.16.3";

  src = fetchurl {
    url = "https://github.com/viarotel-org/escrcpy/releases/download/v${version}/Escrcpy-${version}-linux-x86_64.AppImage";
    sha256 = "sha256-f4Q84ILxDWycbR81JlHzz+SJ4VIChFx1YojbkBY9GUo=";
  };

  dontUnpack = true;

  icon = fetchurl {
    url = "https://raw.githubusercontent.com/viarotel-org/escrcpy/bb802943b19ecf9a6d094f6f0816c26d67cb39b9/electron/resources/build/logo.png";
    sha256 = "sha256-KYvrwftIGfxjEImqDU8iIwqWUWeTPiejtrH3e1Gy0jw=";
  };

  buildInputs = with pkgs; [ ];
  nativeBuildInputs = with pkgs; [
    makeWrapper
    copyDesktopItems
  ];

  installPhase = ''
    runHook preInstall
    _install() {
      mkdir -p $out/{bin,lib/escrcpy}
      ln -s $src $out/lib/escrcpy/escrcpy.AppImage
      install -Dm644 $icon $out/share/icons/hicolor/48x48/apps/escrcpy.png
      makeWrapper ${appimage-run}/bin/appimage-run $out/bin/escrcpy-appimage \
      --argv0 "escrcpy" \
      --add-flags "$out/lib/escrcpy/escrcpy.AppImage"
    }
    _install
    runHook postInstall
  '';

  desktopItems = lib.toList (makeDesktopItem {
    name = "Escrcpy";
    genericName = "Escrcpy";
    exec = "escrcpy-appimage";
    icon = "escrcpy";
    comment = "Scrcpy Powered by Electron";
    desktopName = "Escrcpy";
    categories = [ "Utility" ];
  });

  meta = with lib; {
    description = "Escrcpy";
    homepage = "https://github.com/viarotel-org/escrcpy";
    # license = licenses.apache;
    platforms = [ "x86_64-linux" ];
    # maintainers = with maintainers; [ Program-Learning ];
  };
}
