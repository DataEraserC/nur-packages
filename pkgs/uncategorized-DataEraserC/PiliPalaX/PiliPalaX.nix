{
  fetchFromGitHub,
  lib,
  pkg-config,
  mpv,
  autoPatchelfHook,
  flutter,
  makeDesktopItem,
  copyDesktopItems,
  alsa-lib,
}:
flutter.buildFlutterApplication rec {
  pname = "PiliPalaX";
  version = "2.1.2.3-unstable-2026-09-04";

  src = fetchFromGitHub {
    owner = "bggRGjQaUbCoE";
    repo = "PiliPlus";
    rev = "837ef862fe7e21eabad126466fcb5edac23aea5f";
    hash = "sha256-aShPT/d3J3lMgB+7szEc3CipG7FoVVm+oBdz43yngX8=";
    fetchSubmodules = true;
  };

  passthru.updateScript = [ (toString ./update.sh) ];

  sourceRoot = "${src.name}";

  pubspecLock = lib.importJSON ./pubspec.lock.json;

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];
  buildInputs = [
    mpv
    alsa-lib
    pkg-config
  ];
  gitHashes = lib.importJSON ./git-hashes.json;

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
