{
  stdenv,
  lib,
}:
stdenv.mkDerivation {
  pname = "aw88399-legion-audio-patch";
  version = "1.0.0";

  src = lib.cleanSource ./source;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -f *.patch $out/
    runHook postInstall
  '';

  meta = {
    description = "Audio patches for aw88399 on Lenovo Legion laptops";
    homepage = "https://github.com/nadimkobeissi/16iax10h-linux-sound-saga";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
