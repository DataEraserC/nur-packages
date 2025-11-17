{
  lib,
  sources,
  pkg-config,
  mpv,
  autoPatchelfHook,
  flutter324,
  makeDesktopItem,
  copyDesktopItems,
  alsa-lib,
}:
flutter324.buildFlutterApplication rec {
  inherit (sources.AAA_PiliPalaX) pname version src;

  sourceRoot = "${src.name}";

  # need more step for pubspec.lock
  autoPubspecLock = src + "/pubspec.lock";

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];
  buildInputs = [
    mpv
    alsa-lib
    pkg-config
  ];
  gitHashes = {
    auto_orientation = "sha256-0QOEW8+0PpBIELmzilZ8+z7ozNRxKgI0BzuBS8c1Fng=";
    chat_bottom_container = "sha256-ZdIJODKh9vVrw3FEcC3wsHnXfTKwW9doTVnrdoJ4pM8=";
    floating = "sha256-CdL6reYyTAMYvwVrFw0rYh4QW9fspOIn/+sA6McUvZs=";
    ns_danmaku = "sha256-OHlKscybKSLS1Jd1S99rCjHMZfuJXjkQB8U2Tx5iWeA=";
    share_plus = "sha256-6vS4ZHugkBhHPVQCS2L02BU24PHMMS+VTsO/GS9mgbI=";
  };

  # copy from xddxdd
  preBuild = ''
    cat <<EOL > lib/build_config.dart
    class BuildConfig {
      static const bool isDebug = false;
      static const String buildTime = '1980-01-01 00:00:00';
      static const String commitHash = '0000000000000000000000000000000000000000';
    }
    EOL
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
    categories = [
      "Network"
      "AudioVideo"
    ];
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
