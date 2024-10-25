{
  UnknownAnimeGamePS-wrapper,
  buildEnv,
  mongodb,
}:
let
  devShellPackages = [
    UnknownAnimeGamePS-wrapper
    mongodb
  ];
in
buildEnv {
  name = "UnknownAnimeGamePS_env";
  paths = devShellPackages;
}
