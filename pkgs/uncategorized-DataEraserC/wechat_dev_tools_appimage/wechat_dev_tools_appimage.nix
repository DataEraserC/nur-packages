{
  fetchurl,
  lib,
  stdenv,
  pkgs,
  appimage-run,
  makeDesktopItem,
  sources,
}:
let
  github_url = "https://github.com/msojocs/wechat-web-devtools-linux";
  package_description = "The development tools for wechat projects";
in
stdenv.mkDerivation rec {
  inherit (sources.wechat-web-devtools-linux_appimage) pname src version;

  dontUnpack = true;

  icon = fetchurl {
    url = "https://github.com/Program-Learning/nur-packages/releases/download/v1.06.2307260-1_wechat_dev_tool_appimage/wechat-devtools.png";
    sha256 = "sha256-E1hGcnTtHN3tH/dYI/iN86osKzEV3fVATWquql2KbZQ=";
  };

  buildInputs = with pkgs; [ ];
  nativeBuildInputs = with pkgs; [
    makeWrapper
    copyDesktopItems
  ];

  installPhase = ''
    runHook preInstall
    _install() {
      mkdir -p $out/{bin,lib/wechat_dev_tools}
      ln -s $src $out/lib/wechat_dev_tools/wechat_dev_tools.AppImage
      install -Dm644 $icon $out/share/icons/hicolor/48x48/apps/wechat_dev_tools.png
      makeWrapper ${appimage-run}/bin/appimage-run $out/bin/wechat_dev_tools_appimage \
      --argv0 "wechat_dev_tools" \
      --add-flags "$out/lib/wechat_dev_tools/wechat_dev_tools.AppImage"
    }
    _install
    runHook postInstall
  '';

  desktopItems = lib.toList (makeDesktopItem {
    name = "Wechat Dev Tools(AppImage)";
    genericName = "The development tools for wechat projects";
    exec = "wechat_dev_tools-appimage";
    icon = "wechat_dev_tools";
    comment = "The development tools for wechat projects";
    mimeTypes = [ "x-scheme-handler/wechatide" ];
    desktopName = "Wechat Dev Tools";
    categories = [
      "Development"
      "WebDevelopment"
      "IDE"
    ];
    startupWMClass = "wechat_devtools";
  });

  meta = with lib; {
    description = package_description;
    homepage = github_url;
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    # maintainers = with maintainers; [ Program-Learning ];
  };
}
