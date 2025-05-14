{
  lib,
  stdenv,
  fetchYarnDeps,
  yarnConfigHook,
  yarnBuildHook,
  nodejs,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  electron,
  sources,
  ...
}:
(stdenv.mkDerivation rec {
  inherit (sources.motrix) src pname version;
  packageJSON = "${src}/package.json";

  offlineCache = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-Otu7o3bRyChYbxGeTXr/aEE7HZEFPifktSHaVtjs6vU=";
  };
  nativeBuildInputs = [
    yarnConfigHook
    yarnBuildHook
    nodejs
    makeWrapper
    copyDesktopItems
  ];

  doDist = false;
  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  yarnBuildScript = "electron-builder";
  yarnBuildFlags = [
    "--dir"
    "--config ${src}/electron-builder.json"
    "-c.electronDist=${electron.dist}"
    "-c.electronVersion=${electron.version}"
  ];
  installPhase = ''
    runHook preInstall

    # resources
    mkdir -p "$out/share/lib/motrix"
    cp -r ./dist/*-unpacked/{locales,resources{,.pak}} "$out/share/lib/motrix"

    # icons
    install -Dm444 static/512x512.png $out/share/icons/hicolor/512x512/apps/motrix.png

    # executable wrapper
    makeWrapper '${electron}/bin/electron' "$out/bin/motrix" \
      --add-flags "$out/share/lib/motrix/resources/app.asar" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --inherit-argv0

    runHook postInstall
  '';
  desktopItems = [
    (makeDesktopItem {
      name = "motrix";
      exec = "motrix";
      icon = "motrix";
      desktopName = "Motrix";
      genericName = "Motrix";
      comment = meta.description;
      categories = [ "Network" ];
      startupWMClass = "motrix";
    })
  ];
  meta = with lib; {
    description = "Full-featured download manager";
    homepage = "https://motrix.app";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "motrix";
    broken = true;
  };
})
