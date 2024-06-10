{
  pkgs ? import <nixpkgs> { },
}:
let
  shell = pkgs.mkShell {
    name = "clang_dev_env";
    packages = with pkgs; [
      clang-tools
      ccls
      llvmPackages.clang # c/c++ tools with clang-tools such as clangd
    ];

    inputsFrom = [ ];

    shellHook = ''
      export DEBUG=1
    '';
  };
in
shell
