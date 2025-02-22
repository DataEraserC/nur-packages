{
  lib,
  stdenv,
  copyDesktopItems,
  makeDesktopItem,
  autoPatchelfHook,
  wrapGAppsHook,
  fontconfig,
  lttng-ust,
  icu,
  openssl,
  xorg,
  sources,
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
  ];
  HostPlatform = stdenv.hostPlatform.system;
  source =
    if lib.elem HostPlatform SupportedPlatforms then
      sources."SteamTools-${HostPlatform}"
    else
      throw "Unsupported platform: ${HostPlatform}";
in
stdenv.mkDerivation rec {
  inherit (source) version pname src;
  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook
    copyDesktopItems
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    fontconfig
    lttng-ust
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "watt-toolkit";
      exec = "watt-toolkit";
      icon = "Watt-Toolkit";
      comment = meta.description;
      desktopName = "Watt Toolkit";
      categories = [ "Utility" ];
    })
  ];

  installPhase = ''
    runHook preInstall
    _install_SteamTools() {
      mkdir -p $out/{SteamTools,bin}
      tar -xzf ${src} -C $out/SteamTools
      patchelf --replace-needed liblttng-ust.so.0 liblttng-ust.so $out/SteamTools/dotnet/shared/Microsoft.NETCore.App/9.0.1/libcoreclrtraceptprovider.so
      install -Dm644 $out/SteamTools/Icons/Watt-Toolkit.png $out/share/icons/hicolor/256x256/apps/Watt-Toolkit.png
      sed -i "s|\$run_path|$out/SteamTools|g" "$out/SteamTools/Steam++.sh"
      ln -s $out/SteamTools/Steam++.sh $out/bin/watt-toolkit
      ln -s $out/SteamTools/Steam++.sh $out/bin/Steam++
      ln -s $out/SteamTools/dotnet/dotnet $out/SteamTools/Steam++
    }
    _install_SteamTools
    runHook postInstall
  '';

  preFixup =
    let
      libpath = lib.makeLibraryPath [
        icu
        openssl
        xorg.libX11
        xorg.libICE
        xorg.libSM
      ];
    in
    ''
      gappsWrapperArgs+=(
        --set LD_LIBRARY_PATH ${libpath}
      )
    '';

  meta = {
    homepage = "https://steampp.net";
    description = "an open source cross-platform multi-purpose game toolkit";
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "watt-toolkit";
    SupportedPlatforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
