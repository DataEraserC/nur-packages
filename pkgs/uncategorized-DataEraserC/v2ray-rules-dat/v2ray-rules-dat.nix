# https://github.com/nykma/nur-packages/blob/master/pkgs/v2ray-rules-dat/default.nix
{
  lib,
  stdenvNoCC,
  unzip,
  v2dat,
  sources,
}:
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
  inherit (sources.AAA_v2ray-rules-dat) pname version src;
  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    unzip ${src}
  '';
  installPhase = ''
    mkdir -p $out/share/v2ray-rules-dat
    cp -r *.txt $out/share/v2ray-rules-dat
    cp -r *.dat $out/share/v2ray-rules-dat
    ${v2dat}/bin/v2dat unpack geoip -o $out/share/v2ray-rules-dat ./geoip.dat
    ${v2dat}/bin/v2dat unpack geosite -o $out/share/v2ray-rules-dat ./geosite.dat
    chmod 444 $out/share/v2ray-rules-dat/*
  '';

  meta = {
    description = "V2Ray 路由规则文件加强版，可代替 V2Ray 官方 geoip.dat 和 geosite.dat，兼容 Shadowsocks-windows、Xray-core、Trojan-Go、leaf 和 hysteria。Enhanced edition of V2Ray rules dat files, compatible with Xray-core, Shadowsocks-windows, Trojan-Go, leaf and hysteria.";
    homepage = "https://github.com/Loyalsoldier/v2ray-rules-dat";
    license = lib.licenses.gpl3;
  };
}
