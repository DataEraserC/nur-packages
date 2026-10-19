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

  installPhase =
    let
      bstar_so_name = "bstar-0.5.10.so";
    in
    # bstar_so_name= "liblightweight-v8-inject.so";
    ''
      runHook preInstall
      mkdir -p $out/lib
      install -Dm755 ${src}/${bstar_so_name} $out/lib/${bstar_so_name}
      ln -svf $out/lib/${bstar_so_name} $out/lib/libbstar.so
      runHook postInstall
    '';

  meta = with lib; {
    maintainers = import ../maintainers.nix;
    description = "V8 injection library that adds ChronoCat support to the QQ NT client";
    homepage = "https://github.com/chrononeko/chronocat";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
