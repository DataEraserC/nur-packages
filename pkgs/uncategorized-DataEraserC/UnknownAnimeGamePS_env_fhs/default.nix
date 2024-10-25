{
  pkgs,
  UnknownAnimeGamePS-wrapper,
  mongodb,
}:
let
  fhs = pkgs.buildFHSEnvChroot {
    name = "UnknownAnimeGamePS_env_fhs";
    targetPkgs =
      pkgs: with pkgs; [
        UnknownAnimeGamePS-wrapper
        mongodb
      ];
    profile = ''
      export FHS=1
    '';
  };
in
pkgs.stdenv.mkDerivation {
  name = "UnknownAnimeGamePS_env_fhs-shell";
  nativeBuildInputs = [ fhs ];
  src = builtins.path { path = ./.; };
  installPhase = ''
    mkdir --mode=0755 --parent $out/bin
    cp -r ${fhs}/bin "$out"
  '';
  shellHook = "exec UnknownAnimeGamePS_env_fhs";
}
