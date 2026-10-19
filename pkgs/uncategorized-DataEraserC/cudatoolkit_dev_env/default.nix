{
  lib,
  pkgs ? import <nixpkgs> { },
}:
let
  devShellPackages = with pkgs; [
    cudatoolkit
  ];
in
pkgs.buildEnv {
  name = "cudatoolkit_dev_env";
  paths = devShellPackages;
  meta = {
    description = "Development environment with the CUDA toolkit";
    homepage = "https://developer.nvidia.com/cuda-toolkit";
    license = lib.licenses.unfree;
    maintainers = import ../maintainers.nix;
  };
}
