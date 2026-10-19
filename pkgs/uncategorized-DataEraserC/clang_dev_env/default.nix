{
  lib,
  pkgs ? import <nixpkgs> { },
}:
let
  devShellPackages = with pkgs; [
    clang-tools
    ccls
    llvmPackages.clang # c/c++ tools with clang-tools such as clangd
  ];
in
pkgs.buildEnv {
  name = "clang_dev_env";
  paths = devShellPackages;
  meta = {
    description = "Development environment with Clang and C language tooling";
    homepage = "https://clang.llvm.org/";
    license = lib.licenses.ncsa;
    maintainers = import ../maintainers.nix;
  };
}
