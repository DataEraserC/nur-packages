{
  lib,
  appimageTools,
  fetchurl,
}:
let
  version = "2.02.2608070-2";

  src = fetchurl {
    url = "https://github.com/msojocs/wechat-web-devtools-linux/releases/download/v${version}/WeChat_Dev_Tools_v${version}_x86_64_linux.AppImage";
    hash = "sha256-ZR9rlKx7iSjW2W2EZ6X4pYYqLuI7S7GgpBFETLWXJjg=";
  };
in
appimageTools.wrapType2 rec {
  pname = "wechat_dev_tools_appimage";
  inherit version src;
  extraPkgs = pkgs: [
    pkgs.libxkbfile
    pkgs.libxshmfence
  ];
  extraInstallCommands =
    let
      appimageContents = appimageTools.extract { inherit pname version src; };
    in
    ''
      mkdir -p $out/share/applications
      cat > $out/share/applications/io.github.msojocs.wechat_devtools.desktop <<'EOF'
      [Desktop Entry]
      Type=Application
      Name=WeChat DevTools
      Comment=WeChat web development tools
      Exec=wechat_dev_tools_appimage %F
      Icon=wechat_dev_tools
      Categories=Development;WebDevelopment;IDE;
      Terminal=false
      EOF
      cp -r ${appimageContents}/usr/share/icons $out/share
    '';

  passthru.updateScript = [ (toString ./update.sh) ];

  meta = {
    description = "The development tools for wechat projects";
    homepage = "https://github.com/msojocs/wechat-web-devtools-linux";
    license = lib.licenses.unfree;
    mainProgram = "wechat_dev_tools_appimage";
    maintainers = import ../maintainers.nix;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
