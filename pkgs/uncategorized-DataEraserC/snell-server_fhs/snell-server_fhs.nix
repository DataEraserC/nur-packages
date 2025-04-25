#https://github.com/jkarni/flake/blob/cb9c3ac7b52e996fe03977b85022a50054892d69/pkgs/snell/default.nix#L15
{
  stdenvNoCC,
  unzip,
  buildFHSEnv,
  writeShellScript,
  lib,
  sources,
  stdenv,
  ...
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "i686-linux"
    "aarch64-linux"
    "aarch32-linux"
  ];
  HostPlatform = stdenv.hostPlatform.system;
  source =
    if lib.elem HostPlatform SupportedPlatforms then
      sources."snell-server-${HostPlatform}"
    else
      throw "Unsupported platform: ${HostPlatform}";
  snell-static = stdenvNoCC.mkDerivation {
    inherit (source) version pname src;
    buildInputs = [ unzip ];

    phases = [
      "unpackPhase"
      "installPhase"
    ];

    unpackPhase = ''
      unzip $src
    '';

    installPhase = ''
      mkdir -p $out
      cp snell-server $out
    '';

    meta = {
      description = "https://manual.nssurge.com/others/snell.html";
      platforms = SupportedPlatforms;
    };
  };
in
buildFHSEnv {
  name = "snell";
  runScript = writeShellScript "snell-run" ''
    exec ${snell-static}/snell-server "$@"
  '';
}
