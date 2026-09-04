{
  fetchFromGitHub,
  lib,
  pkg-config,
  flutter,
  makeDesktopItem,
  copyDesktopItems,
}:
let
  pname_zh = "酷市场";
  appname = "c001apk-flutter";
in
flutter.buildFlutterApplication rec {
  pname = "c001apk-flutter";
  version = "0-unstable-2026-03-08";

  src = fetchFromGitHub {
    owner = "Integral-Tech";
    repo = "c001apk-flutter";
    rev = "b6ada6ee8233a9e813b672b8f92faf5e20057457";
    hash = "sha256-AsZpLON3hh+Ei3cArplHQSY/2gDLoiCvJBXM08fvTA4=";
    fetchSubmodules = true;
  };

  passthru.updateScript = [ (toString ./update.sh) ];

  sourceRoot = "${src.name}";
  pubspecLock = lib.importJSON ./pubspec.lock.json;

  nativeBuildInputs = [
    pkg-config
    copyDesktopItems
  ];

  postInstall = ''
    _postinstall() {
      for n in 16 32 48 64 128 256 1024; do
        size=$n"x"$n
        install -Dm644 ${src}/assets/icon/icon.png $out/share/icons/hicolor/$size/apps/${pname}.png
      done
    }
    _postinstall
  '';

  desktopItems = lib.toList (makeDesktopItem {
    name = pname;
    genericName = pname;
    exec = appname;
    icon = pname;
    comment = pname;
    desktopName = pname;
    categories = [ "Network" ];
    extraConfig = {
      "Name[en_US]" = pname;
      "Name[zh_CN]" = pname_zh;
      "Name[zh_TW]" = pname_zh;
      "Comment[zh_CN]" = pname_zh;
      "Comment[zh_TW]" = pname_zh;
    };
  });

  meta = {
    description = "c001apk";
    homepage = "https://github.com/bggRGjQaUbCoE/c001apk-flutter";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = appname;
  };
}
