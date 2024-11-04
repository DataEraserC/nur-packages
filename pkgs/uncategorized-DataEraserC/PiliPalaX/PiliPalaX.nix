{
  lib,
  sources,
  pkg-config,
  flutter,
  makeDesktopItem,
  copyDesktopItems,
  alsa-lib,
}:
flutter.buildFlutterApplication rec {
  inherit (sources.PiliPalaX) pname version src;

  sourceRoot = "${src.name}";

  # need more step for pubspec.lock
  autoPubspecLock = src + "/pubspec.lock";

  nativeBuildInputs = [
    pkg-config
    copyDesktopItems
    alsa-lib
  ];
  buildInputs = [
    pkg-config
    alsa-lib
  ];
  gitHashes = {
    auto_orientation = "sha256-0QOEW8+0PpBIELmzilZ8+z7ozNRxKgI0BzuBS8c1Fng=";
    chat_bottom_container = "sha256-ZdIJODKh9vVrw3FEcC3wsHnXfTKwW9doTVnrdoJ4pM8=";
    floating = "sha256-CdL6reYyTAMYvwVrFw0rYh4QW9fspOIn/+sA6McUvZs=";
    ns_danmaku = "sha256-OHlKscybKSLS1Jd1S99rCjHMZfuJXjkQB8U2Tx5iWeA=";
    share_plus = "sha256-6vS4ZHugkBhHPVQCS2L02BU24PHMMS+VTsO/GS9mgbI=";
  };

  preBuild = ''
    export ALSA_LIBRARIES=${alsa-lib}/lib
    export ALSA_INCLUDE_DIRS=${alsa-lib.dev}/include
  '';

  postInstall = ''
    _postinstall() {
      for n in 16 32 48 64 128 256 1024; do
        size=$n"x"$n
        install -Dm644 ${src}/assets/images/logo/logo_android_2.png $out/share/icons/hicolor/$size/apps/${pname}.png
      done
    }
    _postinstall
  '';

  desktopItems = lib.toList (makeDesktopItem {
    name = pname;
    genericName = pname;
    exec = pname;
    icon = pname;
    comment = pname;
    desktopName = pname;
    categories = [ "Network" ];
    extraConfig = {
      "Name[en_US]" = pname;
      "Name[zh_CN]" = pname;
      "Name[zh_TW]" = pname;
      "Comment[zh_CN]" = pname;
      "Comment[zh_TW]" = pname;
    };
  });
  meta = {
    description = pname;
    homepage = "https://github.com/bggRGjQaUbCoE/PiliPalaX";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    broken = true;
  };
}
