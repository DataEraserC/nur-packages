{
  lib,
  fetchurl,
  appimageTools,
}:
let
  pname = "dingtalk";
  version = "2.1.13";
  name = "${pname}-${version}";
  src = fetchurl {
    url = "https://github.com/nashaofu/dingtalk/releases/download/v${version}/${name}-latest-x86_64.AppImage";
    sha256 = "0z1nli1f3miri3i44b725avxlp6c5pyyxlqqf80mjpkg8y8zv70c";
  };
in
appimageTools.wrapType2 {
  inherit name src;
  meta = {
    description = "DingTalk desktop messaging application";
    homepage = "https://www.dingtalk.com/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
