{
  fetchgit,
  lib,
  stdenv,
  unstableGitUpdater,
}:
stdenv.mkDerivation {
  pname = "aw88399-legion-firmware";
  version = "0-unstable-2026-09-18";

  src = fetchgit {
    url = "https://github.com/Apps-Used-By-Myself/16iax10h-linux-sound-saga";
    rev = "fbb8280a2e0c21a74c8b59322b066f2d565fbc91";
    hash = "sha256-Fsjf8Dt75ZCqeUE4CoggNp1BNAv0c2cCAQ9yTL/TTgI=";
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
