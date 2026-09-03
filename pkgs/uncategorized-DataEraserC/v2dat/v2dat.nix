# https://github.com/nykma/nur-packages/blob/master/pkgs/v2dat/default.nix
{
  fetchFromGitHub,
  lib,
  buildGoModule,
  unstableGitUpdater,
}:
let
  vendorHash = "sha256-ndWasQUHt35D528PyGan6JGXh5TthpOhyJI2xBDn0zI=";
in
buildGoModule {
  pname = "v2dat";
  version = "unstable-2022-12-15";
  inherit vendorHash;

  src = fetchFromGitHub {
    owner = "urlesistiana";
    repo = "v2dat";
    rev = "47b8ee51fb528e11e1a83453b7e767a18d20d1f7";
    hash = "sha256-dJld4hYdfnpphIEJvYsj5VvEF4snLvXZ059HJ2BXwok=";
    fetchSubmodules = true;
  };

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/urlesistiana/v2dat";
  };

  meta = {
    description = "Cli tool that can unpack v2ray data packages. (Note: This project is for fun ONLY. You should build your own data dirctly from upstreams instead of unpacking a v2ray data pack.)";
    homepage = "https://github.com/urlesistiana/v2dat";
    license = lib.licenses.gpl3;
  };
}
