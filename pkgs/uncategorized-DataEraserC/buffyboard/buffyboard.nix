{
  lib,
  stdenv,
  fetchFromGitLab,
  meson,
  ninja,
  pkg-config,
  libinput,
  libxkbcommon,
  libevdev,
}:

stdenv.mkDerivation {
  pname = "buffyboard";
  version = "unstable-2023-11-20";

  src = fetchFromGitLab {
    owner = "postmarketOS";
    repo = "buffybox";
    rev = "14b30c60183d98e8d0b4dadf66198e08badf631e";
    hash = "sha256-9wLuTAqYoFl+IAR1ixp0nHwh6jBWl+1jDPhhxqE+LHQ=";
    fetchSubmodules = true;
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
