{
  fetchzip,
  stdenvNoCC,
  pkgs,
  lib,
  ...
}:
let
  package_nane = "MIO-KITCHEN";
  package_type = "bin";
  package_version = "3.0.8";
  github_release_tag = "CI_BUILD_264";
  github_url = "https://github.com/ColdWindScholar/MIO-KITCHEN-SOURCE";
  package_description = "The Android Rom Tool Use python language";
in
stdenvNoCC.mkDerivation rec {
  pname = "${package_nane}_${package_type}";
  version = package_version;

  src = fetchzip {
    url = "${github_url}/releases/download/${github_release_tag}/MIO-KITCHEN-${package_version}-linux.zip";
    hash = "sha256-EjRufKlXYVtxIuJJ+OXe4jk93XgnnH3cvShzuYh+L5c=";
    stripRoot = false;
  };

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    # zlib
  ];
  installPhase = ''
    runHook preInstall
    _install() {
      mkdir -p $out/{bin,MIO-KITCHEN}
      cp -r ${src}/* $out/MIO-KITCHEN
      echo ${src}
      chmod a+x $out/MIO-KITCHEN/tool
    }
    _install
    runHook postInstall
  '';

  preFixup = ''
    makeWrapper $out/MIO-KITCHEN/tool $out/bin/MIO-KITCHEN
  '';

  meta = with lib; {
    description = package_description;
    homepage = github_url;
    # do not upload to cachix
    # license = licenses.gpl3;
    platforms = [ "x86_64-linux" ];
    # maintainers = with maintainers; [ Program-Learning ];
    broken = true;
  };
}
