{
  pkgs,
  poetry2nix,
  lib,
  sources,
}:
let
  inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication;
in
mkPoetryApplication {
  overrides = poetry2nix.overrides.withDefaults (
    _final: prev: {
      evdev = prev.evdev.override {
        preferWheel = true;
      };
    }
  );
  projectDir = sources.OpenFreebuds.src;
  meta = {
    description = "Open source app for HUAWEI FreeBuds (Linux + Windows)";
    longDescription = ''
      FOSS Windows/Linux client for HUAWEI FreeBuds headset series
    '';
    homepage = "https://github.com/melianmiko/OpenFreebuds";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
    broken = true;
  };
}
