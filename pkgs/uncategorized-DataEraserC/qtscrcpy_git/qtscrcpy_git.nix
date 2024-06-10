{
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  qttools,
  qtx11extras,
  ffmpeg,
  openssh,
  wrapQtAppsHook,
  copyDesktopItems,
  android-tools,
  scrcpy,
  makeDesktopItem,
  lib,
}:
stdenv.mkDerivation rec {
  pname = "qtscrcpy";
  version = "2.2.1";

  src = fetchFromGitHub {
    owner = "barry-ran";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-Yu39b+HBZh1QLZMsps6S7wYMokQ4H+ncENr/fdVs8s0=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    openssh
    pkg-config
    wrapQtAppsHook
    copyDesktopItems
  ];
  buildInputs = [
    qttools
    qtx11extras
    ffmpeg
  ];

  postPatch = ''
    substituteInPlace ./QtScrcpy/main.cpp \
      --replace "../../../QtScrcpy/QtScrcpyCore/src/third_party/adb/linux/adb" "${android-tools}/bin/adb" \
      --replace "../../../QtScrcpy/QtScrcpyCore/src/third_party/scrcpy-server" "${scrcpy}/share/scrcpy/scrcpy-server"
  '';

  installPhase = ''
    mkdir -p $out/bin/
    cp ../output/linux/release/QtScrcpy $out/bin/
    mkdir -p $out/share/pixmaps/
    cp ${src}/backup/logo.png $out/share/pixmaps/${pname}.png
    runHook postInstall
  '';

  # https://aur.archlinux.org/cgit/aur.git/tree/qtscrcpy.desktop?h=qtscrcpy
  desktopItems = lib.toList (makeDesktopItem {
    name = pname;
    type = "Application";
    icon = pname;
    desktopName = "QtScrcpy";
    exec = "QtScrcpy";
    terminal = false;
    categories = [
      "Development"
      "Utility"
    ];
    comment = "Android real-time screencast control tool";
  });

  meta = with lib; {
    description = "Android real-time display control software";
    homepage = "https://github.com/barry-ran/QtScrcpy";
    license = licenses.asl20;
    # maintainers = with maintainers; [ Program-Learning ];
    platforms = platforms.linux;
    # https://github.com/NixOS/nixpkgs/issues/195117
    broken = true;
  };
}
# https://github.com/NixOS/nixpkgs/commit/d896f0d8e02d3a251e595761807eb9656a221685
