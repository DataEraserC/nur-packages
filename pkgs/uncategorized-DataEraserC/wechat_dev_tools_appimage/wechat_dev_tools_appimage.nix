{
  lib,
  appimageTools,
  fetchurl,
}:
let
  version = "2.01.2510290-2";

  src = fetchurl {
    url = "https://github.com/msojocs/wechat-web-devtools-linux/releases/download/v${version}/WeChat_Dev_Tools_v${version}_x86_64_linux.AppImage";
    hash = "sha256-NcIxmzttKtrVjXoFW6l4FqHXZEklqLxPjkRSZh4T594=";
  };
in
appimageTools.wrapType2 rec {
  pname = "wechat_dev_tools_appimage";
  inherit version src;
  extraPkgs =
    pkgs: with pkgs; [
      gnome2.GConf
      xorg.libxkbfile
      xorg.libxshmfence
    ];
  extraInstallCommands =
    let
      appimageContents = appimageTools.extractType2 { inherit pname version src; };
    in
    ''
      install -Dm444 ${appimageContents}/io.github.msojocs.wechat_devtools.desktop -t $out/share/applications
      cp -r ${appimageContents}/usr/share/icons $out/share
    '';

  passthru.updateScript = [ (toString ./update.sh) ];

  meta = {
    description = "The development tools for wechat projects";
    homepage = "https://github.com/msojocs/wechat-web-devtools-linux";
    license = lib.licenses.unfree;
    mainProgram = "wechat-web-devtools-linux_appimage";
    maintainers = with lib.maintainers; [ Guanran928 ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
