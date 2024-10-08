{
  lib,
  mihomo,
  callPackage,
  fetchFromGitHub,
  fetchurl,
  dbip-country-lite,
  stdenv,
  wrapGAppsHook3,
  v2ray-geoip,
  v2ray-domain-list-community,
}:
let
  pname = "clash-nyanpasu";
  version = "1.4.5";

  src = fetchurl {
    url = "https://github.com/keiko233/clash-nyanpasu/releases/download/v${version}/clash-nyanpasu_${version}_amd64.deb";
    hash = "sha256-cxaq7Rndf0ytEaqc7CGQix5SOAdsTOoTj1Jlhjr5wEA=";
  };

  src-service = fetchFromGitHub {
    owner = "clash-verge-rev";
    repo = "clash-verge-service";
    rev = "e74e419f004275cbf35a427337d3f8c771408f07"; # no meaningful tags in this repo. The only way is updating manully every time.
    hash = "sha256-HyRTOqPj4SnV9gktqRegxOYz9c8mQHOX+IrdZlHhYpo=";
  };

  meta-unwrapped = {
    description = "Clash GUI based on tauri";
    homepage = "https://github.com/clash-verge-rev/clash-verge-rev";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [
      Guanran928
      bot-wxt1221
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };

  service-cargo-hash = "sha256-FeCpzUYeSqpcXF9JS2ZKH3YqpQ1bzf9h/9ZzH6j4D28=";

  service = callPackage ./service.nix {
    inherit
      version
      src-service
      service-cargo-hash
      pname
      ;
    meta = meta-unwrapped;
  };

  webui = callPackage ./webui.nix {
    inherit
      version
      src
      pname
      ;
    meta = meta-unwrapped;

  };

  sysproxy-hash = "sha256-TEC51s/viqXUoEH9rJev8LdC2uHqefInNcarxeogePk=";

  unwrapped = callPackage ./unwrapped.nix {
    inherit
      pname
      version
      src
      sysproxy-hash
      webui
      ;
    meta = meta-unwrapped;
  };

  meta = {
    description = "Clash GUI based on tauri";
    homepage = "https://github.com/keiko233/clash-nyanpasu";
    license = lib.licenses.gpl3Only;
    mainProgram = "clash-nyanpasu";
    maintainers = with lib.maintainers; [
      Guanran928
      bot-wxt1221
    ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
in
stdenv.mkDerivation {
  inherit
    pname
    src
    version
    meta
    ;

  nativeBuildInputs = [
    wrapGAppsHook3
  ];
  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share,lib/clash-verge/resources}
    cp -r ${unwrapped}/share/* $out/share
    cp -r ${unwrapped}/bin/clash-verge $out/bin/clash-verge
    # This can't be symbol linked. It will find mihomo in its runtime path
    ln -s ${service}/bin/clash-verge-service $out/bin/clash-verge-service
    ln -s ${mihomo}/bin/mihomo $out/bin/verge-mihomo
    # people who want to use alpha build show override mihomo themselves. The alpha core entry was removed in clash-verge.
    ln -s ${v2ray-geoip}/share/v2ray/geoip.dat $out/lib/clash-verge/resources/geoip.dat
    ln -s ${v2ray-domain-list-community}/share/v2ray/geosite.dat $out/lib/clash-verge/resources/geosite.dat
    ln -s ${dbip-country-lite.mmdb} $out/lib/clash-verge/resources/Country.mmdb
    runHook postInstall
  '';
}
