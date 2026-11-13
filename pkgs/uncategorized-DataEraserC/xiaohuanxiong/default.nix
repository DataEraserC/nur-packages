{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  patchelf,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-core,
  bashInteractive,
  bubblewrap,
  cairo,
  coreutils,
  cups,
  dbus,
  expat,
  fontconfig,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxscrnsaver,
  libxtst,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  util-linux,
  xdg-utils,
  zlib,
}:
let
  version = "1.2.0";

  plat =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  debArch = if stdenv.hostPlatform.isx86_64 then "amd64" else "arm64";

  hash =
    {
      x86_64-linux = "sha256-aydYFA/zX4PsYsTXozIqNSTmndf0744HwWVPdp5ux3U=";
      aarch64-linux = "sha256-qtaG1Yj3+Wchyrnxhu8HhCqJpY+ituW1oShDTukd+0w=";
    }
    .${stdenv.hostPlatform.system};

  libraries = [
    alsa-lib
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxscrnsaver
    libxtst
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    util-linux
    xdg-utils
    zlib
  ];

  # Where the generic Linux builds the app downloads look for their loader.
  loaderDir = if stdenv.hostPlatform.isAarch64 then "/lib" else "/lib64";
  loaderName =
    if stdenv.hostPlatform.isAarch64 then "ld-linux-aarch64.so.1" else "ld-linux-x86-64.so.2";

  # glibc is on the library path for those downloaded binaries; everything else
  # is what the Electron process itself needs.
  runtimeLibPath = lib.makeLibraryPath (libraries ++ [ stdenv.cc.libc ]);
in
stdenv.mkDerivation (finalAttrs: {
  pname = "xiaohuanxiong";
  inherit version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    name = "xiaohuanxiong-${version}-${debArch}.deb";
    url = "https://sta-volc.xiaohuanxiong.com/office-agent/linux/${plat}/%E5%95%86%E6%B1%A4%E5%B0%8F%E6%B5%A3%E7%86%8A-${version}-${debArch}.deb";
    inherit hash;
  };

  nativeBuildInputs = [
    dpkg
    patchelf
    wrapGAppsHook3
  ];

  buildInputs = libraries ++ [
    bashInteractive
    coreutils
  ];

  # The bundled Nuitka agent runtime carries a small trailer after its last
  # section, and its self-loading breaks if patchelf rewrites more than the
  # interpreter, so only the interpreter is patched and nothing is stripped.
  # dontPatchELF keeps the stdenv fixup hook from rewriting the same ELFs a
  # second time.
  dontStrip = true;
  dontPatchELF = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share
    cp -r "opt/商汤小浣熊" $out/opt/xiaohuanxiong
    chmod +x $out/opt/xiaohuanxiong/raccoon-ai

    # Node native bindings ship every platform's prebuilt binary; keep only the
    # ones this host can load.
    find $out/opt/xiaohuanxiong/resources -name '*.node' -print0 |
      while IFS= read -r -d "" node; do
        case "$node" in
          *win32* | *darwin* | *linux-arm-* | *linux-ia32-* | *musl*) rm -f "$node" ;;
        esac
      done
    rm -rf $out/opt/xiaohuanxiong/resources/node_modules/@koromix/koffi-linux-${
      if stdenv.hostPlatform.isx86_64 then "arm64" else "x64"
    }

    # autoPatchelfHook is not used: it adds a RUNPATH to every ELF it finds,
    # which makes the Nuitka runtime (`box-agent-acp`) segfault while parsing
    # its own image. Rewriting only the interpreter leaves its layout intact.
    for exe in \
      raccoon-ai \
      chrome-sandbox \
      chrome_crashpad_handler; do
      patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} "$out/opt/xiaohuanxiong/$exe"
    done

    # The agent runtime is also spawned with a sanitized environment that drops
    # LD_LIBRARY_PATH (its own MCP children), so its dependencies are rewritten
    # to absolute store paths. A RUNPATH is not an option: patchelf 0.19 adds a
    # segment for it and the Nuitka runtime then segfaults parsing itself.
    patchelf \
      --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
      --replace-needed libz.so.1 ${lib.getLib zlib}/lib/libz.so.1 \
      --replace-needed libc.so.6 ${lib.getLib stdenv.cc.libc}/lib/libc.so.6 \
      --replace-needed libdl.so.2 ${lib.getLib stdenv.cc.libc}/lib/libdl.so.2 \
      --replace-needed libpthread.so.0 ${lib.getLib stdenv.cc.libc}/lib/libpthread.so.0 \
      "$out/opt/xiaohuanxiong/resources/box-agent-runtime/bin/box-agent-acp"

    cp -r usr/share/icons $out/share/icons
    # The app sets CHROME_DESKTOP=raccoon-ai.desktop on Linux, so the window's
    # app id only resolves to an icon and a launcher entry when the file keeps
    # that name; a different file name leaves the window with a generic icon.
    install -Dm644 usr/share/applications/raccoon-ai.desktop \
      $out/share/applications/raccoon-ai.desktop

    substituteInPlace $out/share/applications/raccoon-ai.desktop \
      --replace-fail 'Exec="/opt/商汤小浣熊/raccoon-ai" %U' "Exec=$out/bin/xiaohuanxiong %U"

    substitute ${./launcher.sh.in} $out/bin/xiaohuanxiong \
      --replace-fail '@app@' "$out/opt/xiaohuanxiong/raccoon-ai" \
      --replace-fail '@bwrap@' '${lib.getExe bubblewrap}' \
      --replace-fail '@loader@' '${stdenv.cc.bintools.dynamicLinker}' \
      --replace-fail '@loaderDir@' '${loaderDir}' \
      --replace-fail '@loaderName@' '${loaderName}' \
      --replace-fail '@libPath@' '${runtimeLibPath}'
    chmod +x $out/bin/xiaohuanxiong

    runHook postInstall
  '';

  passthru = {
    updateScript = [ (toString ./update.sh) ];
    aiProvenance = [
      {
        agent = "dsh";
        model = "deepseek-v4.1-flash";
        involvement = "authored";
      }
    ];
  };

  meta = {
    description = "SenseTime Raccoon Work AI office assistant desktop client";
    homepage = "https://xiaohuanxiong.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
    mainProgram = "xiaohuanxiong";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
