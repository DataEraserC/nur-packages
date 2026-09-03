{
  sources,
  stdenv,
  lib,
}:
stdenv.mkDerivation {
  pname = "aw88399-legion-firmware";

  inherit (sources.AAA_16iax10h-linux-sound-saga) version src;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/firmware
    cp -f fix/firmware/aw88399_acf.bin $out/lib/firmware/
    runHook postInstall
  '';

  meta = {
    description = "Firmware for aw88399 audio codec on Lenovo Legion laptops";
    homepage = "https://github.com/nadimkobeissi/16iax10h-linux-sound-saga";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
