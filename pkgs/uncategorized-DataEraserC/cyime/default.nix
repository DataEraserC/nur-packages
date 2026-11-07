{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  makeBinaryWrapper,
  python3,
  librime,
  rime-data,
  ibus,
  gtk3,
  gobject-introspection,
  dbus,
  glib,
  pango,
  atk,
  gdk-pixbuf,
  cairo,
  harfbuzz,
  qt6,
  iproute2,
  unstableGitUpdater,
}:

let
  python = python3.withPackages (ps: [
    ps.pyqt6
    ps.pygobject3
    ps.cryptography
    ps.qrcode
    ps.pillow
    ps.zeroconf
    ps.pyyaml
    ps.python-xlib
  ]);

  rimeAssets = fetchFromGitHub {
    owner = "kingzcheung";
    repo = "rime-wubi";
    rev = "a9d394b6abf1c9223c22830f3e5c6b61b57740c1";
    hash = "sha256-Z0DMtvziiOZk0RQhhEZnmW59TY12KiKNI2CcfL4vTN4=";
  };

  giPath = lib.makeSearchPath "lib/girepository-1.0" [
    ibus
    gtk3
    gobject-introspection
    glib
    pango
    atk
    gdk-pixbuf
    cairo
  ];

  libPath = lib.makeLibraryPath [
    librime
    ibus
    gtk3
    gobject-introspection
    glib
    pango
    atk
    gdk-pixbuf
    cairo
    harfbuzz
  ];

  qtPluginPath = lib.makeSearchPath "lib/qt-6/plugins" [
    qt6.qtbase
    qt6.qtwayland
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "cyime";
  version = "0-unstable-2026-10-31";
  src = fetchFromGitHub {
    owner = "tuxKOH";
    repo = "CyIME";
    rev = "d177333626fcc8a69c39419527809a57e084d094";
    hash = "sha256-CAfzSkWiZP++jhrHdc1FvMuBhTi0Zyu1nhpOytXSsj0=";
  };
  __structuredAttrs = true;
  strictDeps = true;
  dontWrapQtApps = true;

  nativeBuildInputs = [
    makeWrapper
    makeBinaryWrapper
    python
  ];

  buildInputs = [
    librime
    rime-data
    ibus
    gtk3
    gobject-introspection
    dbus
    glib
    pango
    atk
    gdk-pixbuf
    cairo
    harfbuzz
    qt6.qtbase
    qt6.qtwayland
    iproute2
  ];

  dontConfigure = true;
  dontBuild = true;
  dontPatchShebangs = true;
  doCheck = true;
  doInstallCheck = true;

  postPatch = ''
    mkdir -p app/src/main/assets
    rm -rf app/src/main/assets/rime
    cp -r ${rimeAssets} app/src/main/assets/rime
  '';

  checkPhase = ''
    runHook preCheck
    export CYIME_RIME_SHARED=${rime-data}/share/rime-data
    export CYIME_RIME_LIBRARY=${librime}/lib/librime.so.1
    export QT_QPA_PLATFORM=offscreen
    export PYTHONDONTWRITEBYTECODE=1
    (cd linux && ${python}/bin/python3 -m unittest tests.test_rime.RimeTests.test_pinyin_candidates_partial_selection_and_commit -v)
    runHook postCheck
  '';

  installPhase = ''
        runHook preInstall
        mkdir -p $out/share/cyime $out/bin $out/share/applications $out/share/ibus/component
        find linux -type d -name __pycache__ -prune -exec rm -rf {} +
        cp -r linux $out/share/cyime/
        mkdir -p $out/share/cyime/app/src/main/assets
        cp -r app/src/main/assets/rime $out/share/cyime/app/src/main/assets/
        install -m644 LICENSE $out/share/cyime/LICENSE

        makeBinaryWrapper ${python}/bin/python3 $out/bin/cyime-python \
          --inherit-argv0 \
          --prefix GI_TYPELIB_PATH : "${giPath}" \
          --prefix LD_LIBRARY_PATH : "${libPath}" \
          --prefix PATH : "${lib.makeBinPath [ iproute2 ]}" \
          --set CYIME_RIME_LIBRARY "${librime}/lib/librime.so.1" \
          --set PYTHONHOME "${python}" \
          --set QT_PLUGIN_PATH "${qtPluginPath}"

        makeWrapper $out/bin/cyime-python $out/bin/cyime \
          --add-flags "$out/share/cyime/linux/run.py"

        makeWrapper $out/bin/cyime-python $out/bin/cyime-setup \
          --add-flags "$out/share/cyime/linux/setup_ibus.py --shared-dir ${rime-data}/share/rime-data" \
          --prefix PATH : "${
            lib.makeBinPath [
              ibus
              dbus
            ]
          }" \
          --prefix IBUS_COMPONENT_PATH : "$out/share/ibus/component"

        makeWrapper $out/bin/cyime-python $out/bin/cyime-ibus-engine \
          --add-flags "$out/share/cyime/linux/ibus_engine.py --ibus --shared-dir ${rime-data}/share/rime-data"

        cat > $out/share/ibus/component/cyime.xml <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <component>
      <name>org.freedesktop.IBus.CyIME</name>
      <description>CyIME Linux Rime frontend</description>
      <exec>$out/bin/cyime-ibus-engine</exec>
      <version>0.1</version>
      <author>CyIME contributors</author>
      <license>GPL-3.0-or-later</license>
      <homepage>https://github.com/Cyletix/CyIME</homepage>
      <textdomain>cyime</textdomain>
      <engines>
        <engine>
          <name>cyime-rime</name>
          <longname>CyIME 拼音</longname>
          <language>zh_CN</language>
          <license>GPL-3.0-or-later</license>
          <author>CyIME contributors</author>
          <icon>input-keyboard</icon>
          <layout>us</layout>
          <rank>80</rank>
        </engine>
      </engines>
    </component>
    EOF

        cat > $out/share/applications/cyime.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=CyIME Clipboard
    Comment=Clipboard history and device pairing for CyIME
    Exec=$out/bin/cyime
    Icon=input-keyboard
    Terminal=false
    Categories=Utility;Qt;
    EOF

        runHook postInstall
  '';

  installCheckPhase = ''
    runHook preInstallCheck
    export QT_QPA_PLATFORM=offscreen
    export PYTHONDONTWRITEBYTECODE=1
    test -x $out/bin/cyime
    test -x $out/bin/cyime-ibus-engine
    test -x $out/bin/cyime-setup
    test -f $out/share/ibus/component/cyime.xml
    $out/bin/cyime --help >/dev/null
    test "$($out/bin/cyime-python -c 'import sys; print(sys.executable)')" = "$out/bin/cyime-python"
    user_dir=$(mktemp -d)
    $out/bin/cyime-setup --user-dir "$user_dir" >/dev/null
    test -f "$user_dir/cyime_pinyin.schema.yaml"
    test -f "$user_dir/default.custom.yaml"
    data_dir=$(mktemp -d)
    XDG_DATA_HOME="$data_dir" XDG_CONFIG_HOME="$data_dir/config" $out/bin/cyime-setup --user-dir "$user_dir" --register >/dev/null
    grep -Fq "$out/bin/cyime-python" "$data_dir/ibus/component/cyime.xml"
    runHook postInstallCheck
  '';

  passthru = {
    aiProvenance = [
      {
        agent = "dsh";
        model = "deepseek-v4-flash";
        involvement = "assisted";
      }
    ];
    updateScript = unstableGitUpdater {
      url = "https://github.com/tuxKOH/CyIME";
      branch = "feat/linux-desktop-preview";
    };
  };

  meta = {
    description = "IBus Rime frontend and clipboard companion from CyIME's Linux preview branch";
    homepage = "https://github.com/tuxKOH/CyIME/tree/feat/linux-desktop-preview";
    license = lib.licenses.gpl3Plus;
    maintainers = import ../maintainers.nix;
    mainProgram = "cyime";
    isIbusEngine = true;
    platforms = lib.platforms.linux;
  };
})
