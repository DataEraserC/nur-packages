{
  lib,
  fetchFromGitLab,
  rustPlatform,
  libevdev,
  pkg-config,
}:
rustPlatform.buildRustPackage rec {
  pname = "hkdm";
  version = "0.2.1-unstable-2023-03-06";

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
    rev = "f47bec2f37547ca775e82ec642a0bc9da419854e";
    hash = "sha256-5MEC6+lVw/McjOUzt7ACbpxzl254eEoQDtFtzfpcyWY=";
  };

  passthru.updateScript = [ (toString ./update.sh) ];

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes = {
    };
  };
  meta = {
    description = "Lighter-weight hotkey daemon";
    homepage = "https://gitlab.com/postmarketOS/hkdm";
    mainProgram = "hkdm";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
}
