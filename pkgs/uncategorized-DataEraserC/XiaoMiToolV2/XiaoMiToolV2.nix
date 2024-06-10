{
  requireFile,
  stdenvNoCC,
  pkgs,
  lib,
  ...
}:
let
  package_nane = "XiaoMiToolV2";
  package_type = "bin";
  package_version = "20.7.28";
  github_release_tag = "v" + package_version;
  github_url = "https://github.com/francescotescari/XiaoMiToolV2";
  package_description = "XiaomiTool V2 - Modding tool for xiaomi devices";
in
stdenvNoCC.mkDerivation rec {
  pname = package_nane + "_" + package_type;
  version = package_version;

  src = requireFile {
    name = "XMT2_Linux_${version}.run";
    url = "${github_url}/releases/download/${github_release_tag}/XMT2_Linux_${version}.run";
    hash = "sha256-vnsjU3bAbRWMJIXuvCK6KZ7nhGOb7lLcUOIQzaIGr8Y=";
  };

  dontUnpack = true;

  nativeBuildInputs = with pkgs; [
    #makeWrapper
    #autoPatchelfHook
  ];
  buildInputs = [ ];
  installPhase = ''
    runHook preInstall
    _install() {
      mkdir -p $out/{bin,XiaoMiToolV2}
      ln -s ${src} $out/bin/XiaoMiToolV2
    }
    _install
    runHook postInstall
  '';
  preFixup = '''';

  meta = with lib; {
    description = package_description;
    homepage = github_url;
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    # maintainers = with maintainers; [ Program-Learning ];
    broken = true;
  };
}
