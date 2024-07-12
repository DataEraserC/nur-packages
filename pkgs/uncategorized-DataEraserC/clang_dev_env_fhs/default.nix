{
  pkgs ? import <nixpkgs> { },
}:
let
  fhs = pkgs.buildFHSEnvChroot {
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
    mkdir --mode=0755 --parent $out/bin
    cp -r ${fhs}/bin "$out"
  '';
  shellHook = "exec clang_dev_env_fhs";
}
