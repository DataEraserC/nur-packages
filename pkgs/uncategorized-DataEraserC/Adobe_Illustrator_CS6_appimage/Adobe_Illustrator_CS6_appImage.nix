{
  appimageTools,
  fetchurl,
  lib,
  p7zip,
  runCommand,
  pkgsi686Linux,
}:
let
  version = "CS6";

  src7z = fetchurl {
    url = "https://github.com/Program-Learning/nur-packages/releases/download/Adobe_Illustrator_CS6.AppImage/Adobe_Illustrator_CS6.AppImage.7z";
    sha256 = "sha256-rbG4qa013jO0cGl3nIE5YarmWDfRVX7GmScMKuwAF9M=";
  };

  icon = fetchurl {
    url = "https://github.com/Program-Learning/nur-packages/releases/download/Adobe_Illustrator_CS6.AppImage/Adobe_Illustrator_CS6.png";
    sha256 = "sha256-zKBp0EyYClUeAuJ79+VJrrBtPuKIoyNTIOpcbwZVLV0=";
  };

  appImage =
    runCommand "Adobe_Illustrator_CS6.AppImage"
      {
        nativeBuildInputs = [ p7zip ];
      }
      ''
        7z x ${src7z} -o"$out" >/dev/null
      '';
in
appimageTools.wrapType2 rec {
  pname = "Adobe_Illustrator_CS6";
  inherit version;

  src = "${appImage}/Adobe_Illustrator_CS6.AppImage";

  extraPkgs = _: [
    pkgsi686Linux.glibc
    pkgsi686Linux.stdenv.cc.cc.lib
  ];

  extraInstallCommands = ''
    install -Dm644 ${icon} $out/share/icons/hicolor/48x48/apps/Adobe_Illustrator_CS6.png
  '';

  meta = {
    description = "Adobe_Illustrator_CS6";
    homepage = "https://t.me/Linux_Appimages/1052";
    license = lib.licenses.unfree;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
