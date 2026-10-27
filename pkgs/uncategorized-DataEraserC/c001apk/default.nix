{
  lib,
  flutter347,
  fetchFromGitHub,
  pkg-config,
  makeDesktopItem,
  copyDesktopItems,
}:
let
  flutter = flutter347;
in
flutter.buildFlutterApplication (finalAttrs: {
  pname = "c001apk";
  version = "1.3.5";

  src = fetchFromGitHub {
    owner = "TG-Twilight";
    repo = "c001apk";
    tag = "${finalAttrs.version}-release";
    hash = "sha256-iv3EgHCP8J0/tZk7OhpOeJSa+9l+EBcMQPbpnvwU38k=";
  };

  sourceRoot = "${finalAttrs.src.name}/apps/flutter";

  pubspecLock = lib.importJSON ./pubspec.lock.json;

  nativeBuildInputs = [
    pkg-config
    copyDesktopItems
  ];

  postPatch = ''
    substituteInPlace linux/my_application.cc \
      --replace-fail \
        'gtk_window_set_icon_from_file(window, "assets/icon/icon.png", NULL);' \
        'gtk_window_set_icon_from_file(window, "${placeholder "out"}/share/icons/hicolor/256x256/apps/${finalAttrs.pname}.png", NULL);'
  '';

  postInstall = ''
    for size in 16 32 48 64 128 256 512 1024; do
      install -Dm644 assets/icon/icon.png \
        $out/share/icons/hicolor/''${size}x''${size}/apps/${finalAttrs.pname}.png
    done
  '';

  desktopItems = [
    (makeDesktopItem {
      name = finalAttrs.pname;
      desktopName = "c001apk";
      genericName = "Coolapk Client";
      exec = "c001apk";
      icon = finalAttrs.pname;
      comment = "Unofficial lightweight Coolapk client";
      categories = [
        "Network"
        "Utility"
      ];
      extraConfig = {
        "Name[zh_CN]" = "c001apk";
        "Comment[zh_CN]" = "轻量、简体中文的非官方酷安客户端";
      };
    })
  ];

  passthru = {
    updateScript = [ (toString ./update.sh) ];
    aiProvenance = [
      {
        agent = "dsh";
        model = "deepseek-v4.1-flash";
        involvement = "assisted";
      }
    ];
  };

  meta = {
    description = "Unofficial lightweight Coolapk client built with Flutter";
    homepage = "https://github.com/TG-Twilight/c001apk";
    license = lib.licenses.agpl3Plus;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.linux;
    mainProgram = "c001apk";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
  };
})
