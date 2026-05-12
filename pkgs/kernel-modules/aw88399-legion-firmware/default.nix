{
  stdenv,
  lib,
}:
stdenv.mkDerivation {
  pname = "aw88399-legion-firmware";
  version = "1.0.0";

  src = lib.cleanSource ./source;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/firmware
    cp -f aw88399_acf.bin $out/lib/firmware/
    runHook postInstall
  '';

  meta = {
    description = "Firmware for aw88399 audio codec on Lenovo Legion laptops";
    homepage = "https://github.com/nadimkobeissi/16iax10h-linux-sound-saga";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
