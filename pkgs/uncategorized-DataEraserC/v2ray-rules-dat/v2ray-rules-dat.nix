# https://github.com/nykma/nur-packages/blob/master/pkgs/v2ray-rules-dat/default.nix
{
  lib,
  stdenvNoCC,
  unzip,
  v2dat,
  fetchurl,
}:
let
  version = "202610272204";

  src = fetchurl {
    url = "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/rules.zip";
    hash = "sha256-X4hLe/ymTFGCZ3Gn6VMAkoFURiZbrRcOgOeL3iTidXM=";
  };
in
# .
# └── share
#     └── v2ray-rules-dat
#         ├── direct-list.txt
#         ├── geoip.dat
#         ├── geoip_*.txt
#         ├── geosite.dat
#         ├── geosite_*.txt
#         ├── proxy-list.txt
#         └── reject-list.txt
stdenvNoCC.mkDerivation rec {
  pname = "v2ray-rules-dat";
  inherit version src;
  nativeBuildInputs = [ unzip ];

  passthru.updateScript = [ (toString ./update.sh) ];

  unpackPhase = ''
    runHook preUnpack
    unzip ${src}
    runHook postUnpack
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/v2ray-rules-dat
    cp -r *.txt $out/share/v2ray-rules-dat
    cp -r *.dat $out/share/v2ray-rules-dat
    ${v2dat}/bin/v2dat unpack geoip -o $out/share/v2ray-rules-dat ./geoip.dat
    ${v2dat}/bin/v2dat unpack geosite -o $out/share/v2ray-rules-dat ./geosite.dat
    chmod 444 $out/share/v2ray-rules-dat/*
    runHook postInstall
  '';

  meta = {
    maintainers = import ../maintainers.nix;
    description = "Enhanced V2Ray routing rules replacing the official geoip.dat and geosite.dat";
    homepage = "https://github.com/Loyalsoldier/v2ray-rules-dat";
    license = lib.licenses.gpl3;
  };
}
