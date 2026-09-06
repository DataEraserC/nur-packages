{
  lib,
  stdenv,
  fetchFromGitLab,
  unstableGitUpdater,
  meson,
  ninja,
  pkg-config,
  libinput,
  libxkbcommon,
  libevdev,
}:

stdenv.mkDerivation {
  pname = "buffyboard";
  version = "3.2.0-unstable-2024-10-05";

  src = fetchFromGitLab {
    owner = "postmarketOS";
    repo = "buffybox";
    rev = "c683350b9fb944e38cb484f04f98e4e3f85b41a5";
    hash = "sha256-z7siroBDauvs8TxfO/h+5HUU5G5aOWwNUxDaZm80I5A=";
    fetchSubmodules = true;
  };

  passthru.updateScript = unstableGitUpdater {
    url = "https://gitlab.com/postmarketOS/buffybox.git";
    tagPrefix = "v";
  };

  # https://gitlab.com/postmarketOS/buffybox/-/issues/1
  hardeningDisable = [ "fortify3" ];

  postPatch = ''
    cd buffyboard
  '';

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    libevdev
    libinput
    libxkbcommon
  ];

  meta = {
    description = "Touch-enabled framebuffer keyboard (not only) for vampire slayers";
    homepage = "https://gitlab.com/postmarketOS/buffybox/-/tree/master/buffyboard";
    license = lib.licenses.gpl3Only;
    maintainers = [ lib.maintainers.chayleaf ];
    mainProgram = "buffyboard";
    platforms = lib.platforms.all;
  };
}
