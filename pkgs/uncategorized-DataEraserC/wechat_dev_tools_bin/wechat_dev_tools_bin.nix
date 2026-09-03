{
  lib,
  stdenv,
  pkgs,
  fetchurl,
  musl,
  nwjs,
  krb5,
  makeDesktopItem,
}:
let
  github_url = "https://github.com/msojocs/wechat-web-devtools-linux";
  package_description = "The development tools for wechat projects";
  version = "2.01.2510290-2";

  src = fetchurl {
    url = "https://github.com/msojocs/wechat-web-devtools-linux/releases/download/v${version}/WeChat_Dev_Tools_v${version}_x86_64_linux.tar.gz";
    hash = "sha256-LyRXmmhfbTIApzoXU9ayOmfRhVJbtQK2n0pJMwQgMuU=";
  };
in
stdenv.mkDerivation rec {
  pname = "wechat_dev_tools_bin";
  inherit version src;

  passthru.updateScript = [ (toString ./update.sh) ];

  nativeBuildInputs = with pkgs; [
    wrapGAppsHook3
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];
  icon = fetchurl {
    url = "https://github.com/Program-Learning/nur-packages/releases/download/v1.06.2307260-1_wechat_dev_tool_appimage/wechat-devtools.png";
    sha256 = "sha256-E1hGcnTtHN3tH/dYI/iN86osKzEV3fVATWquql2KbZQ=";
  };

  installPhase = ''
    runHook preInstall
    _package-ide() {
      mkdir -p $out/{bin,share/applications,WeChat_Dev_Tools}


      tar xzf ${src} -C $out/WeChat_Dev_Tools --strip-components=1

      install -Dm644 ${icon} $out/share/icons/hicolor/48x48/apps/wechat_dev_tools.png

      substituteInPlace $out/WeChat_Dev_Tools/bin/wechat-devtools \
        --replace "#!/bin/bash" "#!${pkgs.bash}/bin/bash"
      ln -s $out/WeChat_Dev_Tools/bin/wechat-devtools $out/bin/wechat_dev_tools_bin
      ln -s $out/WeChat_Dev_Tools/bin/wechat-devtools $out/bin/wechat_dev_tools-bin
    }
    _package-ide
    runHook postInstall
  '';

  desktopItems = lib.toList (makeDesktopItem {
    name = "Wechat_Dev_Tools";
    genericName = "Wechat_Dev_Tools";
    exec = "wechat_dev_tools_bin";
    icon = "wechat_dev_tools";
    comment = "wechat_dev_tools";
    desktopName = "Wechat Dev Tools";
    categories = [
      "Development"
      "WebDevelopment"
      "IDE"
    ];
  });
  libraries = with pkgs; [
    musl
    nwjs
    #glibc
    #curl
    #nss
    #libdrm
    #nspr
    #alsa-lib
    xorg.libxkbfile
    krb5
    #mesa
    #xorg.libxshmfence
  ];

  buildInputs = with pkgs; libraries;

  runtimeLibs = pkgs.lib.makeLibraryPath libraries;

  meta = {
    description = package_description;
    homepage = github_url;
    license = lib.licenses.unfree;
    mainProgram = "wechat_dev_tools_bin";
    platforms = [ "x86_64-linux" ];
  };
}
