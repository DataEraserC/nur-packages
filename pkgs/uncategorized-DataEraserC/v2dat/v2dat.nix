# https://github.com/nykma/nur-packages/blob/master/pkgs/v2dat/default.nix
{
  lib,
  buildGoModule,
  sources,
}:
let
  vendorHash = "sha256-ndWasQUHt35D528PyGan6JGXh5TthpOhyJI2xBDn0zI=";
in
buildGoModule {
  inherit vendorHash;
  inherit (sources.AAA_v2dat) src pname version;

  meta = {
    description = "Cli tool that can unpack v2ray data packages. (Note: This project is for fun ONLY. You should build your own data dirctly from upstreams instead of unpacking a v2ray data pack.)";
    homepage = "https://github.com/urlesistiana/v2dat";
    license = lib.licenses.gpl3;
  };
}
