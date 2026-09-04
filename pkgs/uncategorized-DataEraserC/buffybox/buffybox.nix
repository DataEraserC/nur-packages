{
  fetchgit,
  lib,
  stdenv,
  unstableGitUpdater,
  inih,
  libdrm,
  libinput,
  libxkbcommon,
  meson,
  ninja,
  pkg-config,
  scdoc,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "buffybox";
  version = "0-unstable-2024-10-05";

  src = fetchgit {
    url = "https://gitlab.com/postmarketOS/buffybox.git";
    rev = "c683350b9fb944e38cb484f04f98e4e3f85b41a5";
    hash = "sha256-z7siroBDauvs8TxfO/h+5HUU5G5aOWwNUxDaZm80I5A=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    scdoc
  ];

  buildInputs = [
    inih
    libdrm
    libinput
    libxkbcommon
  ];

  propagatedBuildInputs = [
    libxkbcommon
  ];

  passthru.updateScript = unstableGitUpdater {
    url = "https://gitlab.com/postmarketOS/buffybox.git";
    hardcodeZeroVersion = true;
  };

  meta = {
    description = "Suite of graphical applications for the terminal";
    mainProgram = "buffyboard";
    homepage = "https://gitlab.com/postmarketOS/buffybox";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
})
