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
    homepage = "https://github.com/nickedwards109/Base16-Builder";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
