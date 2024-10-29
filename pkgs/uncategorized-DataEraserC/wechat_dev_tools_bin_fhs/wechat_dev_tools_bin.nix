{
  fetchzip,
  lib,
  stdenv,
  pkgs,
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

  nativeBuildInputs = with pkgs; [
    wrapGAppsHook
    autoPatchelfHook
    makeWrapper
  ];

  installPhase = ''
    _package-ide() {
      mkdir -p $out/bin

      cp -r ${src} $out/WeChat_Dev_Tools_${github_release_tag}_x86_64_linux
      
      substituteInPlace $out/WeChat_Dev_Tools_${github_release_tag}_x86_64_linux/bin/wechat-devtools  \
        --replace "#!/bin/bash" "#!/usr/bin/env bash"
      ln -s $out/WeChat_Dev_Tools_${github_release_tag}_x86_64_linux/bin/wechat-devtools $out/bin/wechat_dev_tools-bin
    }
    _package-ide
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

  buildInputs = with pkgs; libraries;

  runtimeLibs = pkgs.lib.makeLibraryPath libraries;

  #preFixup = ''
  #  makeWrapper $out/share/io.github.msojocs.wechat-devtools-linux/io.github.msojocs.wechat-devtools-linux/files/bin/bin/wechat-devtools $out/bin/wechat_dev_tools-deb \
  #    --prefix LD_LIBRARY_PATH : "${runtimeLibs}" \
  #    "''${gappsWrapperArgs[@]}"
  #'';

  meta = with lib; {
    description = package_description;
    homepage = github_url;
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    # maintainers = with maintainers; [ Program-Learning ];
  };
}
