{
  lib,
  appimageTools,
  sources,
  ...
}:
appimageTools.wrapType2 rec {
  inherit (sources.flutter_server_box_appimage) pname version src;
  extraPkgs = pkgs: with pkgs; [ libepoxy ];
  meta = {
    description = "flutter_server_box";
    homepage = "https://github.com/lollipopkit/flutter_server_box/";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
