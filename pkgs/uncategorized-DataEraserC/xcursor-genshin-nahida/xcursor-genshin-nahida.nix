{
  lib,
  stdenvNoCC,
  fetchgit,
}:
stdenvNoCC.mkDerivation rec {
  pname = "xcursor-genshin-nahida";
  version = "1.0-2";

  src = fetchgit {
    url = "https://aur.archlinux.org/xcursor-genshin-nahida.git";
    rev = "3a6d21a337925f47466c74d16c413e7be6ee58e4";
    hash = "sha256-I8UVUlfoqVXRstehGyFumq8oE5cLxRs6DKvcHol1AQk=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/icons
    tar -xf xcursor-genshin-nahida.tar.gz --directory=$out/share/icons

    runHook postInstall
  '';

  meta = {
    description = "xcursor genshin nahida";
    homepage = "https://aur.archlinux.org/packages/xcursor-genshin-nahida";
    platforms = lib.platforms.linux;
    license = lib.licenses.gpl3;
  };
}
