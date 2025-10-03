{
  lib,
  sources,
  pkg-config,
  flutter335,
  makeDesktopItem,
  copyDesktopItems,
}:
flutter335.buildFlutterApplication rec {
  inherit (sources.flutter_server_box) pname version src;

  sourceRoot = "${src.name}";
  autoPubspecLock = src + "/pubspec.lock";

  nativeBuildInputs = [
    pkg-config
    copyDesktopItems
  ];

  gitHashes = {
    "circle_chart" = "sha256-BcnL/hRf+Yv2U8Nkl7pc8BtncBW+M2by86jO5IbFIRk=";
    "computer" = "sha256-qaD6jn78zDyZBktwJ4WTQa8oCvCWQJOBDaozBVsXNb8=";
    "dartssh2" = "sha256-bS916CwUuOKhRyymtmvMxt7vGXmlyiLep4AZsxRJ6iU=";
    "fl_build" = "sha256-CSKe2yEIisftM0q79HbDTghShirWg02zi9v+hD5R57g=";
    "fl_lib" = "sha256-+eHUpn89BI7k/MbCp09gUWGMlqLBrxOy9PgL9uXnkDI=";
    "plain_notification_token" = "sha256-Cy1/S8bAtKCBnjfDEeW4Q2nP4jtwyCstAC1GH1efu8I=";
    "watch_connectivity" = "sha256-9TyuElr0PNoiUvbSTOakdw1/QwWp6J2GAwzVHsgYWtM=";
    "xterm" = "sha256-LTCMaGVqehL+wFSzWd63KeTBjjU4xCyuhfD9QmQaP0Q=";
  };
  postInstall = ''
    _postinstall() {
      for n in 16 32 48 64 128 256 512 1024; do
        size=$n"x"$n
        install -Dm644 ${src}/assets/app_icon.png $out/share/icons/hicolor/$size/apps/${pname}.png
      done
    }
    _postinstall
  '';
  desktopItems = lib.toList (makeDesktopItem {
    name = pname;
    genericName = pname;
    exec = "ServerBox";
    icon = pname;
    comment = pname;
    desktopName = pname;
    categories = [ "Network" ];
    extraConfig = {
      "Name[en_US]" = pname;
    };
  });
  meta = {
    description = "flutter_server_box";
    homepage = "https://github.com/lollipopkit/flutter_server_box";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "ServerBox";
  };
}
