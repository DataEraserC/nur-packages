# MIT
# # Using it:
#
# let
#   appimagelauncher = (pkgs.libsForQt5.callPackage ./somewhere/appimagelauncher-deb.nix {});
# in
# {
#   environment.systemPackages = with pkgs; [ appimagelauncher ];
#
#   systemd.user.services.appimage-launcherd = {
#     description = "AppImage Launcher";
#     wantedBy = [ "appimage-launcherd.target" ];
#     serviceConfig = {
#       Type = "simple";
#       ExecStart = "${appimagelauncher}/bin/appimagelauncherd";
#     };
#   };
# }
{
  fetchurl,
  lib,
  stdenv,
  dpkg,
  autoPatchelfHook,
  pkgs,
  glib,
  qtbase,
  wrapQtAppsHook,
  librsvg,
  cairo,
  curlFull,
  libsForQt5,
}:
let
  version = "2.2.0";

  src = fetchurl {
    url = "https://github.com/TheAssassin/AppImageLauncher/releases/download/v2.2.0/appimagelauncher_2.2.0-travis995.0f91801.bionic_amd64.deb";
    sha256 = "sha256:0zqaqxalb3zwmcqd5z5k1im9yslq29v1a52b0y8x0zdslrbdpfgl";
  };
in
stdenv.mkDerivation rec {
  name = "appimagelauncher-${version}";

  system = "x86_64-linux";

  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    wrapQtAppsHook
  ];

  buildInputs = [
    glib
    qtbase
    librsvg
    cairo
    curlFull
    libsForQt5.qt5.qtwayland
  ];

  libraries = with pkgs; [
    glib
    libsForQt5.qt5.qtbase
    librsvg
    cairo
    curlFull
    libsForQt5.qt5.qtwayland
  ];

  runtimeLibs = pkgs.lib.makeLibraryPath libraries;

  unpackPhase = ''
    mkdir -p $out
    dpkg -x $src $out
  '';

  # Extract and copy executable in $out/bin
  installPhase = ''
    runHook preInstall

    mv $out/usr/{lib,share} $out
    mkdir $out/bin
    ln -s $out/usr/bin/{ail-cli,appimagelauncherd,AppImageLauncherSettings,AppImageLauncher} $out/bin

    # fix perm
    chmod 555 $out/lib/x86_64-linux-gnu/appimagelauncher/{libappimage.so.1.0.3,libappimageupdate-qt.so,libappimageupdate.so,libbinfmt-bypass-preload.so}

    # Path replacement
    substituteInPlace $out/lib/binfmt.d/appimage.conf  \
      --replace "/usr/bin/" "$out/bin/"

    substituteInPlace $out/lib/systemd/user/appimagelauncherd.service  \
      --replace "/usr/bin/" "$out/bin/"

    # .desktop replacement
    substituteInPlace $out/share/applications/appimagelauncher.desktop \
      --replace "AppImageLauncher" "$out/bin/AppImageLauncher"

    substituteInPlace $out/share/applications/appimagelaunchersettings.desktop  \
      --replace "AppImageLauncherSettings" "$out/bin/AppImageLauncherSettings"

    # Try to patch libraries
    addAutoPatchelfSearchPath $out/lib/x86_64-linux-gnu/appimagelauncher
    addAutoPatchelfSearchPath $out/lib/

    runHook postInstall
  '';

  postFixup = ''
    #patchelf \
    #  --add-needed libcurl.so.4 \
    #  $out/lib/x86_64-linux-gnu/appimagelauncher/libappimageupdate.so
  '';

  meta = with lib; {
    description = "appimagelauncher";
    homepage = "https://github.com/TheAssassin/AppImageLauncher";
    license = licenses.mit;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
  };
}
# https://gist.github.com/socherbyc/019dba5281023b2c2b4329975a1dc655
