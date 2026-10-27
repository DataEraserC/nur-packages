{
  fetchgit,
  lib,
  stdenv,
  unstableGitUpdater,
}:
stdenv.mkDerivation {
  pname = "aw88399-legion-firmware";
  version = "0-unstable-2026-10-26";

  src = fetchgit {
    url = "https://github.com/Apps-Used-By-Myself/16iax10h-linux-sound-saga";
    rev = "ec4ba22542bf56f2443a4935152aeae2c33e6e6c";
    hash = "sha256-iSCG5EfWuMOhbYtfoEQsP9H5IX602YZPYb0WKqJOkZI=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/firmware
    cp -f fix/firmware/aw88399_acf.bin $out/lib/firmware/
    runHook postInstall
  '';

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/Apps-Used-By-Myself/16iax10h-linux-sound-saga";
    hardcodeZeroVersion = true;
  };

  meta = {
    description = "Firmware for aw88399 audio codec on Lenovo Legion laptops";
    homepage = "https://github.com/nadimkobeissi/16iax10h-linux-sound-saga";
    license = lib.licenses.unfree;
    maintainers = import ../../uncategorized-DataEraserC/maintainers.nix;
    platforms = [ "x86_64-linux" ];
  };
}
