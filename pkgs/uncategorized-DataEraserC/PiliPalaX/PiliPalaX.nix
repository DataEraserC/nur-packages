{
  lib,
  sources,
  pkg-config,
  mpv,
  autoPatchelfHook,
  flutter,
  makeDesktopItem,
  copyDesktopItems,
  alsa-lib,
}:
flutter.buildFlutterApplication rec {
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
    chat_bottom_container = "sha256-um9KwZUDxWBhFsGHfv00TjPzxDHmp43TLRF0GwuV1xs=";
    floating = "sha256-0Xd9dsXJCQ/r/8Nb16oM+M8Jdw+r4QzGmU++HpqF/v0=";
    canvas_danmaku = "sha256-54fkcRZDn6GL+7HyNAAPaFiUvOCXQgIN/2KZJetZS/c=";
    extended_nested_scroll_view = "sha256-Vjv5zp5c0Xob1H8/U0+lUueLqOKo7qwusOCchdt3Z7M=";
    file_picker = "sha256-yOZwX6GrA+91WtpXuVf7eM5gdI6mxmdxkSe+dgnHvj4=";
    flutter_sortable_wrapper = "";
    flutter_sortable_wrap = "sha256-Qj9Lzh+pJy+vHznGt5M3xwoJtaVtt00fxm4JJXL4bFI=";
    get = "sha256-BZpvFkz8AKHbAl1v4MxCQLOz+u0fE/7feMFHCZ8fYNk=";
    material_design_icons_flutter = "sha256-KMwjnzJJj8nemCqUCSwYafPOwTYbtoHNenxstocJtz4=";
    media_kit = "sha256-M8z6KGoKrhYFpnXnP+5sHjHMGJe04djKTxnkvLVtBtU=";
    media_kit_libs_android_video = "sha256-M8z6KGoKrhYFpnXnP+5sHjHMGJe04djKTxnkvLVtBtU=";
    media_kit_libs_video = "sha256-M8z6KGoKrhYFpnXnP+5sHjHMGJe04djKTxnkvLVtBtU=";
    media_kit_libs_windows_video = "sha256-M8z6KGoKrhYFpnXnP+5sHjHMGJe04djKTxnkvLVtBtU=";
    media_kit_native_event_loop = "sha256-M8z6KGoKrhYFpnXnP+5sHjHMGJe04djKTxnkvLVtBtU=";
    media_kit_video = "sha256-M8z6KGoKrhYFpnXnP+5sHjHMGJe04djKTxnkvLVtBtU=";
    super_sliver_list = "sha256-G24uRql1aIc1TDJwKqwQ72Pi4YbJybMn6lxOUySSDwk=";
    webdav_client = "sha256-euNF7HdDtZ68BqSEq9BvO10BK09MxX2wWGoElFS0yeE=";
    window_manager = "sha256-UAN3uOXKMfWk+G9GTHyhD2dGDojKA76mGbUR+EFc2Qo=";
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
