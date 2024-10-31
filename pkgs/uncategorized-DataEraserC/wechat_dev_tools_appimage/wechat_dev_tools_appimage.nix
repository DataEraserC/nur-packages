{
  lib,
  appimageTools,
  nix-update-script,
  sources,
}:
appimageTools.wrapType2 rec {
  inherit (sources.wechat-web-devtools-linux_appimage) pname src version;
  dontUnpack = true;

  extraInstallCommands =
    let
      appimageContents = appimageTools.extractType2 { inherit pname version src; };
    in
    ''
      install -Dm444 ${appimageContents}/io.github.msojocs.wechat_devtools.desktop -t $out/share/applications
      cp -r ${appimageContents}/usr/share/icons $out/share
    '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "The development tools for wechat projects";
    homepage = "https://github.com/msojocs/wechat-web-devtools-linux";
    license = lib.licenses.gpl3Plus;
    mainProgram = "wechat-web-devtools-linux_appimage";
    maintainers = with lib.maintainers; [ Guanran928 ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
