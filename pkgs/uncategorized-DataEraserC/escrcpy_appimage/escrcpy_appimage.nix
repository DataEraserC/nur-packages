{
  lib,
  appimageTools,
  fetchurl,
  nix-update-script,
}:
appimageTools.wrapType2 rec {
  pname = "escrcpy";
  version = "3.2.0";

  src = fetchurl {
    url = "https://github.com/viarotel-org/escrcpy/releases/download/v${version}/Escrcpy-${version}-linux-x86_64.AppImage";
    sha256 = "sha256-VUn/N6BZnCunUTv/2uSh4JJETLAhjIsgKgdgAdJTCmY=";
  };

  dontUnpack = true;

  extraInstallCommands =
    let
      appimageContents = appimageTools.extractType2 { inherit pname version src; };
    in
    ''
      install -Dm444 ${appimageContents}/escrcpy.desktop -t $out/share/applications
      cp -r ${appimageContents}/usr/share/icons $out/share
    '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Clash GUI based on tauri";
    homepage = "https://github.com/keiko233/clash-nyanpasu";
    license = lib.licenses.gpl3Plus;
    mainProgram = "escrcpy";
    maintainers = [ lib.maintainers.Guanran928 ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
