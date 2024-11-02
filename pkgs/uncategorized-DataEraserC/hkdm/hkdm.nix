{
  lib,
  fetchFromGitLab,
  rustPlatform,
  libevdev,
  pkg-config,
}:
rustPlatform.buildRustPackage rec {
  pname = "hkdm";
  version = "0.2.1";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    libevdev
  ];

  src = fetchFromGitLab {
    domain = "gitlab.com";
    owner = "postmarketOS";
    repo = "hkdm";
    rev = version;
    hash = "sha256-5MEC6+lVw/McjOUzt7ACbpxzl254eEoQDtFtzfpcyWY=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes =
      {
      };
  };
  meta = {
    description = "Lighter-weight hotkey daemon";
    homepage = "https://gitlab.com/postmarketOS/hkdm";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
