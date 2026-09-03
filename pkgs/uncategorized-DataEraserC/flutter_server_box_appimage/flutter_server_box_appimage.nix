{
  lib,
  appimageTools,
  fetchurl,
}:
let
  version = "1.0.1553";

  src = fetchurl {
    url = "https://github.com/lollipopkit/flutter_server_box/releases/download/v${version}/ServerBox_v${version}_amd64.AppImage";
    hash = "sha256-naFZX4jmwFjgBoEOD+nxtafnBbPh7sfIJjQd/nWcxgo=";
  };
in
appimageTools.wrapType2 rec {
  pname = "flutter_server_box_appimage";
  inherit version src;
  extraPkgs = pkgs: with pkgs; [ libepoxy ];

  passthru.updateScript = [ (toString ./update.sh) ];

  meta = {
    description = "flutter_server_box";
    homepage = "https://github.com/lollipopkit/flutter_server_box/";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
