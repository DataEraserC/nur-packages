{
  fetchgit,
  lib,
  stdenv,
  unstableGitUpdater,
}:
stdenv.mkDerivation {
  pname = "aw88399-legion-audio-patch";
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
