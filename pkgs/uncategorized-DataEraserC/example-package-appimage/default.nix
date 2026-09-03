{
  lib,
  fetchurl,
  appimageTools,
}:
let
  pname = "dingtalk";
  version = "2.1.22";
  name = "${pname}-${version}";
  src = fetchurl {
    url = "https://github.com/nashaofu/dingtalk/releases/download/v${version}/${name}-latest-x86_64.AppImage";
    sha256 = "sha256-oKaKD+ZT5DQgwaDQD8vmlNTm6+5Ar6jr+miytqhzy9Y=";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;
  meta = {
    description = "DingTalk desktop messaging application";
    homepage = "https://www.dingtalk.com/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    broken = true;
  };
}
