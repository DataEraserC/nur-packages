{
  fetchgit,
  lib,
  stdenvNoCC,
  unstableGitUpdater,
  bash,
  autoPatchelfHook,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "ttyescape";
  version = "unstable-2023-03-08";

  src = fetchgit {
    url = "https://gitlab.com/postmarketOS/ttyescape.git";
    rev = "810a195f19f68e817d95da5169b1fc4f22242630";
    hash = "sha256-HUAxjUelCvMgS7zHMXI4vPbyUe+wBMpL23xjPRzIaWY=";
  };
  nativeBuildInputs = [
    autoPatchelfHook
  ];

  postInstall = ''
    sed -i "s@#!/bin/sh@${bash}/bin/bash@g" $out/bin/togglevt.sh
    sed -i "s@/usr/bin/togglevt.sh@$out/bin/togglevt.sh@g" $out/etc/hkdm/config.d/ttyescape.toml
  '';
  installPhase = ''
    runHook preInstall
    _install() {
      install -Dm755 ${src}/togglevt.sh $out/bin/togglevt.sh
      install -Dm755 ${src}/ttyescape-hkdm.toml $out/etc/hkdm/config.d/ttyescape.toml
    }
    _install
    runHook postInstall
  '';

  passthru.updateScript = unstableGitUpdater {
    url = "https://gitlab.com/postmarketOS/ttyescape.git";
    hardcodeZeroVersion = true;
  };

  meta = {
    description = "ttyescape";
    homepage = "https://gitlab.com/postmarketOS/ttyescape";
    mainProgram = "togglevt.sh";
    maintainers = with lib.maintainers; [ ];
  };
}
