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
    maintainers = with lib.maintainers; [ xddxdd ];
    description = "Firmware for aw88399 audio codec on Lenovo Legion laptops";
    homepage = "https://github.com/nickedwards109/Base16-Builder";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
