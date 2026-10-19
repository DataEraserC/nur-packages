{
  lib,
  pkgs ? import <nixpkgs> { },
}:
let
  fhs = pkgs.buildFHSEnv {
    name = "clang_dev_env_fhs";
    targetPkgs =
      pkgs: with pkgs; [
        clang-tools
        ccls
        llvmPackages.clang # c/c++ tools with clang-tools such as clangd
      ];
    profile = ''
      export FHS=1
    '';
  };
in
pkgs.stdenv.mkDerivation {
  name = "clang_dev_env_fhs-shell";
  nativeBuildInputs = [ fhs ];
  src = builtins.path { path = ./.; };
  installPhase = ''
    runHook preInstall
    mkdir --mode=0755 --parent $out/bin
    cp -r ${fhs}/bin "$out"
    runHook postInstall
  '';
  shellHook = "exec clang_dev_env_fhs";
  meta = {
    description = "FHS sandbox providing Clang and C language tooling";
    homepage = "https://clang.llvm.org/";
    license = lib.licenses.ncsa;
    maintainers = import ../maintainers.nix;
  };
}
