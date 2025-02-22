# bstar/default.nix
{
  stdenv,
  lib,
  autoPatchelfHook,
  glibc,
  gcc,
}:
stdenv.mkDerivation rec {
  pname = "bstar";
  version = "0.5.10";

  src = ./.;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    glibc
    gcc.cc.lib
  ];

  installPhase = ''
    mkdir -p $out/lib
    install -Dm755 ${src}/bstar-0.5.10.so $out/lib/bstar-0.5.10.so
    ln -svf $out/lib/bstar-0.5.10.so $out/lib/libbstar.so

  '';

  meta = with lib; {
    description = "BStar compatibility library";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
