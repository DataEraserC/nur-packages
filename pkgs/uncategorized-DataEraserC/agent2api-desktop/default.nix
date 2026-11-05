{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
  pkg-config,
  wrapGAppsHook3,
  glib,
  gtk3,
  webkitgtk_4_1,
  libsoup_3,
  librsvg,
  libayatana-appindicator,
  gsettings-desktop-schemas,
  hicolor-icon-theme,
  copyDesktopItems,
  makeDesktopItem,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "agent2api-desktop";
  version = "3.4.1";

  src = fetchFromGitHub {
    owner = "aimod-cc";
    repo = "Agent2API";
    tag = "v${finalAttrs.version}";
    hash = "sha256-17xzNr7PaoOlOFlBmtvJPt5VwUl9BYLYmSmP8eD624A=";
  };

  cargoRoot = "desktop-tauri/src-tauri";
  buildAndTestSubdir = "desktop-tauri/src-tauri";

  cargoHash = "sha256-hVjhaBxsdj6tkLH+aW07P1SHBWoqZpp5br3zpuvigZk=";

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook3
    copyDesktopItems
  ];

  buildInputs = [
    glib
    gtk3
    webkitgtk_4_1
    libsoup_3
    librsvg
    libayatana-appindicator
    gsettings-desktop-schemas
    hicolor-icon-theme
  ];

  doCheck = false;
  doInstallCheck = false;

  preFixup = ''
    gappsWrapperArgs+=(
      "--prefix" "LD_LIBRARY_PATH" ":" "${lib.makeLibraryPath [ libayatana-appindicator ]}"
    )
  '';

  postInstall = ''
    mv $out/bin/workbuddy-proxy-desktop $out/bin/agent2api
    rm -f $out/lib/libworkbuddy_proxy_desktop_lib.*

    mkdir -p $out/lib/Agent2API/_up_
    cp -r ${finalAttrs.src}/desktop-tauri/ui $out/lib/Agent2API/_up_/ui

    install -Dm644 ${finalAttrs.src}/desktop-tauri/src-tauri/icons/128x128@2x.png \
      $out/share/icons/hicolor/256x256/apps/agent2api.png
    install -Dm644 ${finalAttrs.src}/desktop-tauri/src-tauri/icons/128x128.png \
      $out/share/icons/hicolor/128x128/apps/agent2api.png
    install -Dm644 ${finalAttrs.src}/desktop-tauri/src-tauri/icons/32x32.png \
      $out/share/icons/hicolor/32x32/apps/agent2api.png
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "agent2api";
      exec = "agent2api";
      icon = "agent2api";
      desktopName = "Agent2API";
      comment = "Multi-provider local gateway with a desktop control panel";
      categories = [
        "Development"
        "Network"
      ];
      startupWMClass = "Agent2API";
    })
  ];

  passthru = {
    updateScript = nix-update-script { };
    aiProvenance = [
      {
        agent = "workbuddy";
        model = "deepseek-v4.1-flash";
        involvement = "authored";
      }
    ];
  };

  meta = {
    changelog = "https://github.com/aimod-cc/Agent2API/releases/tag/v${finalAttrs.version}";
    description = "Desktop control panel for the multi-provider AI client gateway, wrapping logins as OpenAI-compatible APIs";
    homepage = "https://github.com/aimod-cc/Agent2API";
    license = lib.licenses.unfree;
    mainProgram = "agent2api";
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.linux;
  };
})
