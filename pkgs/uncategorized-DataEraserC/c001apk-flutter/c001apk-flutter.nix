{
  lib,
  sources,
  pkg-config,
  flutter,
  makeDesktopItem,
  copyDesktopItems,
}:
flutter.buildFlutterApplication rec {
  inherit (sources.c001apk-flutter) pname version src;

  sourceRoot = "${src.name}";
  autoPubspecLock = src + "/pubspec.lock";

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
    exec = pname;
    icon = pname;
    comment = pname;
    desktopName = pname;
    categories = [ "Network" ];
    extraConfig = {
      "Name[en_US]" = pname;
      "Name[zh_CN]" = "酷市场";
      "Name[zh_TW]" = "酷市场";
      "Comment[zh_CN]" = "酷市场";
      "Comment[zh_TW]" = "酷市场";
    };
  });
  meta = {
    description = "c001apk";
    homepage = "https://github.com/bggRGjQaUbCoE/c001apk-flutter";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
  };
}
