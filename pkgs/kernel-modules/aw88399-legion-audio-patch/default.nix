{
  fetchgit,
  lib,
  stdenv,
  unstableGitUpdater,
}:
stdenv.mkDerivation {
  pname = "aw88399-legion-audio-patch";
  version = "0-unstable-2026-10-05";

  src = fetchgit {
    url = "https://github.com/Apps-Used-By-Myself/16iax10h-linux-sound-saga";
    rev = "fba2666cec31b713e13cfd94eef18aa896697747";
    hash = "sha256-Rk+fUu8V9iuvytWh4/VSs/4fF70v3UJ2Di4lU7hLgdU=";
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
    platforms = [ "x86_64-linux" ];
  };
}
