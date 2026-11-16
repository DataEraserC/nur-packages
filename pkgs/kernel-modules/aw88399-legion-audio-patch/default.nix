{
  fetchgit,
  lib,
  stdenv,
  unstableGitUpdater,
}:
stdenv.mkDerivation {
  pname = "aw88399-legion-audio-patch";
  version = "0-unstable-2026-11-16";

  src = fetchgit {
    url = "https://github.com/Apps-Used-By-Myself/16iax10h-linux-sound-saga";
    rev = "040497b3f2e7183679f31f8bff7d512b17bb4702";
    hash = "sha256-59B0nwInjl+6cP2T3ykJb45lQ9AHaWg4GpAaEeM5y3E=";
  };

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -f patch-archive/*.patch $out/
    runHook postInstall
  '';

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/Apps-Used-By-Myself/16iax10h-linux-sound-saga";
    hardcodeZeroVersion = true;
  };

  meta = {
    description = "Audio patches for aw88399 on Lenovo Legion laptops";
    homepage = "https://github.com/nadimkobeissi/16iax10h-linux-sound-saga";
    license = lib.licenses.gpl3Only;
    maintainers = import ../../uncategorized-DataEraserC/maintainers.nix;
    platforms = [ "x86_64-linux" ];
  };
}
