{
  fetchFromGitHub,
  lib,
  pkg-config,
  flutter335,
  makeDesktopItem,
  copyDesktopItems,
}:
flutter335.buildFlutterApplication rec {
  pname = "flutter_server_box";
  version = "1.0.1130-unstable-2025-04-25";

  src = fetchFromGitHub {
    owner = "Apps-Used-By-Myself";
    repo = "flutter_server_box";
    rev = "8f09085cf30f9b48209c7c3c1e9dceac5aa5eeeb";
    hash = "sha256-D2FzL34FV+7FnxyEVi/Rm2qO3c9eQmCjlH/4pMWlU5s=";
    fetchSubmodules = true;
  };

  passthru.updateScript = [ (toString ./update.sh) ];

  sourceRoot = "${src.name}";
  pubspecLock = lib.importJSON ./pubspec.lock.json;

  nativeBuildInputs = [
    pkg-config
    copyDesktopItems
  ];

  gitHashes = lib.importJSON ./git-hashes.json;
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
