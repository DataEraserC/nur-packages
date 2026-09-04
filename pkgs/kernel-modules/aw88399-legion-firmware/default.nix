{
  fetchgit,
  lib,
  stdenv,
  unstableGitUpdater,
}:
stdenv.mkDerivation {
  pname = "aw88399-legion-firmware";
  version = "0-unstable-2026-09-03";

  src = fetchgit {
    url = "https://github.com/Apps-Used-By-Myself/16iax10h-linux-sound-saga";
    rev = "c87dae9e8307c205dc1f8a75fa369f0c35928831";
    hash = "sha256-mAj11frNVyoHzgYfY3OqkTjhYu7sEeLjjCNtoNwN4xs=";
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
    platforms = [ "x86_64-linux" ];
  };
}
