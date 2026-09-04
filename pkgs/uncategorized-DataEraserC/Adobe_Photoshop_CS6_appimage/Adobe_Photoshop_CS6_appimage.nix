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
    url = "https://github.com/Program-Learning/nur-packages/releases/download/Adobe_Photoshop_CS6.AppImage/Adobe_Photoshop_CS6.AppImage.7z";
    sha256 = "sha256-U19wx0asTuu6o/AvUrp2AM1bywwJAfH5R7H4zdVPj+A=";
  };

  icon = fetchurl {
    url = "https://github.com/Program-Learning/nur-packages/releases/download/Adobe_Photoshop_CS6.AppImage/Adobe_Photoshop_CS6.png";
    sha256 = "sha256-IZ6Lb3eNg0M0HTHj0Vw5N1EJa07FYlzXuueoBHfyVMU=";
  };

  appImage =
    runCommand "Adobe_Photoshop_CS6.AppImage"
      {
        nativeBuildInputs = [ p7zip ];
      }
      ''
        7z x ${src7z} -o"$out" >/dev/null
      '';
in
appimageTools.wrapType2 rec {
  pname = "Adobe_Photoshop_CS6";
  inherit version;

  src = "${appImage}/Adobe_Photoshop_CS6.AppImage";

  extraPkgs =
    _: with pkgsi686Linux; [
      glibc
      stdenv.cc.cc.lib
      freetype
      fontconfig
      zlib
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xorg.libXrandr
      xorg.libXcursor
      xorg.libXfixes
      xorg.libXi
      xorg.libXxf86vm
      xorg.libXinerama
      xorg.libXcomposite
      xorg.libxcb
      xorg.libXau
      xorg.libXdmcp
    ];

  extraInstallCommands = ''
    install -Dm644 ${icon} $out/share/icons/hicolor/48x48/apps/Adobe_Photoshop_CS6.png
  '';

  meta = {
    description = "Adobe_Photoshop_CS6";
    homepage = "https://t.me/Linux_Appimages/1042";
    license = lib.licenses.unfree;
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
