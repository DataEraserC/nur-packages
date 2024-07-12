{
  fetchurl,
  fetchzip,
  lib,
  stdenv,
  pkgs,
  makeDesktopItem,
}:
let
  package_nane = "wechat_dev_tools";
  package_type = "bin";
  package_version = "1.06.2402040-1";
  github_release_tag = "v${package_version}";
  github_url = "https://github.com/msojocs/wechat-web-devtools-linux";
  package_description = "The development tools for wechat projects";
in
stdenv.mkDerivation rec {
  pname = "${package_nane}_${package_type}";
  version = package_version;

  src = fetchzip {
    url = "${github_url}/releases/download/${github_release_tag}/WeChat_Dev_Tools_${github_release_tag}_x86_64_linux.tar.gz";
    sha256 = "sha256-PU/1fyyDB3Q7W+BzOa58nd9lEtb8F95vJ5RkHcmL0IY=";
  };
  icon = fetchurl {
    url = "https://github.com/Program-Learning/nur-packages/releases/download/v1.06.2307260-1_wechat_dev_tool_appimage/wechat-devtools.png";
    sha256 = "sha256-E1hGcnTtHN3tH/dYI/iN86osKzEV3fVATWquql2KbZQ=";
  };
  nativeBuildInputs = with pkgs; [
    wrapGAppsHook
    autoPatchelfHook
    # makeWrapper
    copyDesktopItems
  ];

  installPhase = ''
    runHook preInstall
    _package-ide() {
      mkdir -p $out/{bin,share/applications}

      cp -r ${src} $out/WeChat_Dev_Tools_${github_release_tag}_x86_64_linux

      install -Dm644 $icon $out/share/icons/hicolor/48x48/apps/wechat_dev_tools.png

      substituteInPlace $out/WeChat_Dev_Tools_${github_release_tag}_x86_64_linux/bin/wechat-devtools  \
        --replace "#!/bin/bash" "#!{pkgs.bash}/bin/bash"
      ln -s $out/WeChat_Dev_Tools_${github_release_tag}_x86_64_linux/bin/wechat-devtools $out/bin/wechat_dev_tools-bin
    }
    _package-ide
    runHook postInstall
  '';

  libraries = with pkgs; [
    nwjs
    #glibc
    #curl
    #nss
    #libdrm
    #nspr
    #alsaLib
    xorg.libxkbfile
    krb5
    #mesa
    #xorg.libxshmfence
  ];

  buildInputs = libraries;

  runtimeLibs = pkgs.lib.makeLibraryPath libraries;

  desktopItems = lib.toList (makeDesktopItem {
    name = "Wechat Dev Tools(Binary)";
    genericName = "The development tools for wechat projects";
    exec = "wechat_dev_tools-bin";
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
