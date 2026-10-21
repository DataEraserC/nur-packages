{
  lib,
  stdenv,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  libevdev,
  libx11,
  libxtst,
  libxfixes,
  wayland,
  lobsterai-unwrapped,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lobsterai-wrapper";
  inherit (lobsterai-unwrapped) version;

  __structuredAttrs = true;
  strictDeps = true;

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "lobsterai";
      desktopName = "LobsterAI";
      genericName = "AI Assistant";
      comment = "AI-assisted coding and productivity tool";
      exec = "lobsterai %U";
      icon = "lobsterai";
      startupWMClass = "LobsterAI";
      mimeTypes = [ "x-scheme-handler/lobsterai" ];
      categories = [ "Utility" ];
      keywords = [
        "AI"
        "assistant"
        "coding"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall

    install -Dm644 ${lobsterai-unwrapped}/opt/lobsterai/resources/app-icon/512x512.png "$out/share/icons/hicolor/512x512/apps/lobsterai.png"

    mkdir -p "$out/bin"
    # dontPatchELF keeps Electron and the native modules on $ORIGIN-relative
    # rpath, so every library they link needs to be on LD_LIBRARY_PATH here:
    # libstdc++ for the modules themselves and, since 2026.10.16, the X11,
    # libevdev and Wayland clients that selection-hook's prebuilt .node needs.
    makeWrapper ${lobsterai-unwrapped}/opt/lobsterai/LobsterAI "$out/bin/lobsterai" \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true --wayland-text-input-version=3}}" \
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          stdenv.cc.cc.lib
          libevdev
          libx11
          libxtst
          libxfixes
          wayland
        ]
      }"

    runHook postInstall
  '';

  passthru = {
    unwrapped = lobsterai-unwrapped;
    aiProvenance = [
      {
        agent = "dsh";
        model = "mimo-v2.6-flash-free";
        involvement = "authored";
      }
      {
        agent = "dsh";
        model = "deepseek-flash";
        involvement = "assisted";
      }
    ];
  };

  meta = {
    description = "Launcher wrapper for LobsterAI with automatic Wayland ozone platform detection";
    homepage = "https://github.com/netease-youdao/LobsterAI";
    license = lib.licenses.mit;
    mainProgram = "lobsterai";
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.linux;
  };
})
