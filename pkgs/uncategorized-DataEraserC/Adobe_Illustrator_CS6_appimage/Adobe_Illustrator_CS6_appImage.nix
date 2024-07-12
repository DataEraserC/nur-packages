{
  fetchurl,
  lib,
  stdenv,
  pkgs,
  appimage-run,
  makeDesktopItem,
}:
stdenv.mkDerivation rec {
  pname = "Adobe_Illustrator_CS6";
  version = "CS6";

  src = fetchurl {
    url = "https://github.com/Program-Learning/nur-packages/releases/download/Adobe_Illustrator_CS6.AppImage/Adobe_Illustrator_CS6.AppImage.7z";
    sha256 = "sha256-rbG4qa013jO0cGl3nIE5YarmWDfRVX7GmScMKuwAF9M=";
  };

  icon = fetchurl {
    url = "https://github.com/Program-Learning/nur-packages/releases/download/Adobe_Illustrator_CS6.AppImage/Adobe_Illustrator_CS6.png";
    sha256 = "sha256-zKBp0EyYClUeAuJ79+VJrrBtPuKIoyNTIOpcbwZVLV0=";
  };

  buildInputs = with pkgs; [ p7zip ];
  nativeBuildInputs = with pkgs; [
    makeWrapper
    copyDesktopItems
  ];

  unpackPhase = ''
    7z x $src
  '';

  installPhase = ''
    runHook preInstall
    _install() {
      mkdir -p $out/Appimage
      ln -s Adobe_Illustrator_CS6.AppImage $out/Appimage/Adobe_Illustrator_CS6.AppImage
      install -Dm644 $icon $out/share/icons/hicolor/48x48/apps/Adobe_Illustrator_CS6.png
      makeWrapper ${appimage-run}/bin/appimage-run $out/bin/adobe_illustrator_cs6 \
      --argv0 "adobe_illustrator_cs6" \
      --add-flags "$out/Appimage/Adobe_Illustrator_CS6.AppImage"
    }
    _install
    runHook postInstall
  '';

  desktopItems = lib.toList (makeDesktopItem {
    name = "Adobe_Illustrator_CS6";
    genericName = "Adobe_Illustrator_CS6";
    exec = "adobe_illustrator_cs6";
    icon = "Adobe_Illustrator_CS6";
    comment = "GameLinux";
    desktopName = "Adobe_Illustrator_CS6";
    categories = [
      "Graphics"
      "2DGraphics"
    ];
  });
  meta = with lib; {
    description = "Adobe_Illustrator_CS6";
    homepage = "https://t.me/Linux_Appimages/1052";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    # maintainers = with maintainers; [ Program-Learning ];
  };
}
