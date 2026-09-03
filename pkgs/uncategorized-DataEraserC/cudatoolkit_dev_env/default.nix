{
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
}
