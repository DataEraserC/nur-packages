{
  lib,
  stdenv,
  dpkg,
  gcc,
  libGL,
  ffmpeg,
  gmic,
  cups,
  speechd,
  xorg,
  nss,
  alsa-lib,
  unixODBC,
  postgresql,
  gnutar,
  openssl,
  gtk3,
  pango,
  cairo,

  makeWrapper,
  autoPatchelfHook,
  wrapQtAppsHook,

  runtimeShell,

  libsForQt5,

  # Qt modules
  qtmultimedia,
  qtlocation,
  qtimageformats,
  qtbase,
  qtwebengine,
  qt3d,
  qtwebsockets,
  qtsensors,
  qtwebview,
  qtgamepad,
  qtserialport,
  qtxmlpatterns,
  qtquickcontrols2,
  qtspeech,
  qtserialbus,
  qtremoteobjects,
  qtscxml,
  # provide libQt5Designer.so
  qttools,
  # provide libQt5Bluetooth.so.5 libQt5Nfc.so.5
  qtconnectivity,
  qtwayland,

  sources,
  ...
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "aarch64-linux"
  ];
  HostPlatform = stdenv.hostPlatform.system;
  source =
    if lib.elem HostPlatform SupportedPlatforms then
      sources."AAA_himirage-${HostPlatform}"
    else
      throw "Unsupported platform: ${HostPlatform}";
in
stdenv.mkDerivation {
  inherit (source) src;
  pname = source.pname + "-unwrapped";
  inherit (sources.AAA_himirage-JSON) version;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    wrapQtAppsHook
    dpkg
  ];

  buildInputs =
    [
      gcc.cc.lib
      libGL
      ffmpeg
      gmic
      cups
      speechd
      xorg.libXtst
      nss
      alsa-lib
      unixODBC
      postgresql
      gnutar
      openssl
      gtk3
      pango
      cairo
    ]
    ++ [
      # Qt modules
      qtmultimedia
      qtlocation
      qtimageformats
      qtbase
      libsForQt5.fcitx5-qt
      qtwebengine
      qt3d
      qtwebsockets
      qtsensors
      qtwebview
      qtgamepad
      qtserialport
      qtxmlpatterns
      qtquickcontrols2
      qtspeech
      qtserialbus
      qtremoteobjects
      qtscxml
      # provide libQt5Designer.so
      qttools
      # provide libQt5Bluetooth.so.5 libQt5Nfc.so.5
      qtconnectivity
      qtwayland
    ];

  # dontWrapQtApps = true;

  # qtWrapperArgs = [
  #   "--set QT_QPA_PLATFORM_PLUGIN_PATH ${qtbase}/${qtbase.qtPluginPrefix}/platforms"
  # ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    dpkg -x $src $out
    chmod -R 755 $out

    # Relocate application files
    mv $out/opt/apps/yeeheart/himirage $out/lib/himirage
    mv $out/usr/share $out/
    rm -rf $out/usr $out/opt

    # Remove bundled Qt libraries to avoid version mismatch
    # rm -rf $out/lib/himirage/lib/qt/libQt5*.so*
    # rm -rf $out/lib/himirage/plugins/{audio,bearer,geoservices,platforminputcontexts}/
    # rm -rf $out/lib/himirage/plugins/geoservices
    # rm -rf $out/lib/himirage/plugins/*
    # rm -rf $out/lib/himirage/lib/qt

    # Create bin directory and symlinks
    mkdir -p $out/bin

    cat << EOF > "$out/bin/himirage"
    #!${runtimeShell}
    $out/lib/himirage/himirage \$@
    EOF

    chmod +x $out/bin/himirage

    wrapProgram $out/bin/himirage \
        --set QT_QPA_PLATFORM_PLUGIN_PATH "${qtbase}/${qtbase.qtPluginPrefix}/platforms"

    ln -s $out/lib/himirage/himirage.sh $out/bin/himirage.sh

    # Update desktop entry
    substituteInPlace $out/share/applications/himirage.desktop \
      --replace-fail "/opt/apps/yeeheart/himirage/himirage.sh" "himirage.sh"

    rm -rf $out/lib/himirage/plugins/wayland-graphics-integration-client
    ln -s ${qtwayland}/lib/qt-*/plugins/* $out/lib/himirage/plugins/

    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://photosir.com";
    mainProgram = "himirage.sh";
    platforms = SupportedPlatforms;
    broken = true;
    license = licenses.unfreeRedistributable;
  };
}
