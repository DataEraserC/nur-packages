{
  lib,
  pkgs ? import <nixpkgs> { },
}:
let
  fhs = pkgs.buildFHSEnvChroot {
    name = "cudatoolkit_dev_env_fhs";
    targetPkgs = pkgs: with pkgs; [ cudatoolkit ];
    profile = ''
      export FHS=1
    '';
  };
in
pkgs.stdenv.mkDerivation {
  name = "cudatoolkit_dev_env_fhs-shell";
  nativeBuildInputs = [ fhs ];
  src = builtins.path { path = ./.; };
  installPhase = ''
    mkdir --mode=0755 --parent $out/bin
    cp -r ${fhs}/bin "$out"
  '';
  meta.license = lib.licenses.unfree;

  shellHook = "exec cudatoolkit_dev_env_fhs";
}
