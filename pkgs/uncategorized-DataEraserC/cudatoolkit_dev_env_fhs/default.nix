{
  lib,
  pkgs ? import <nixpkgs> { },
}:
let
  fhs = pkgs.buildFHSEnv {
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
    runHook preInstall
    mkdir --mode=0755 --parent $out/bin
    cp -r ${fhs}/bin "$out"
    runHook postInstall
  '';
  meta.license = lib.licenses.unfree;
  meta.description = "FHS sandbox providing the CUDA toolkit";
  meta.homepage = "https://developer.nvidia.com/cuda-toolkit";
  meta.maintainers = import ../maintainers.nix;

  shellHook = "exec cudatoolkit_dev_env_fhs";
}
