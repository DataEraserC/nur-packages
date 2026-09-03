{
  lib,
  stdenv,
  copyDesktopItems,
  makeDesktopItem,
  autoPatchelfHook,
  wrapGAppsHook3,
  fetchurl,
  fontconfig,
  lttng-ust,
  icu,
  openssl,
  xorg,
}:
let
  HostPlatform = stdenv.hostPlatform.system;

  version =
    {
      x86_64-linux = "3.1.0";
      aarch64-linux = "3.0.0-rc.16";
      x86_64-darwin = "3.1.0";
    }
    .${HostPlatform} or (throw "Unsupported platform: ${HostPlatform}");

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://github.com/BeyondDimension/SteamTools/releases/download/3.1.0/Steam++_v3.1.0_linux_x64.tgz";
        hash = "sha256-+5m81PpqxkkihwD5CIGf4ZoWzCmoZq1D0oc+UEpBeD8=";
      };
      aarch64-linux = fetchurl {
        url = "https://github.com/BeyondDimension/SteamTools/releases/download/3.0.0-rc.16/Steam++_v3.0.0-rc.16_linux_arm64.tgz";
        hash = "sha256-xfzxxxMKsoMww9PzB/nvRcxqOqyn65escvxkzK9csCo=";
      };
      x86_64-darwin = fetchurl {
        url = "https://github.com/BeyondDimension/SteamTools/releases/download/3.1.0/Steam++_v3.1.0_macos.dmg";
        hash = "sha256-ft6K3rim8xHHAZOh48ZPN4UlVayrrfS8QXMZa+CrNas=";
      };
    }
    .${HostPlatform} or (throw "Unsupported platform: ${HostPlatform}");
in
stdenv.mkDerivation rec {
  pname = "watt-toolkit_bin";
  inherit version src;
  sourceRoot = ".";

  passthru.updateScript = [ (toString ./update.sh) ];

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
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
      patchelf --replace-needed liblttng-ust.so.0 liblttng-ust.so $out/SteamTools/dotnet/shared/Microsoft.NETCore.App/*/libcoreclrtraceptprovider.so || echo "ignore error"
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
