{
  fetchurl,
  lib,
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  dpkg,
  libGL,
  at-spi2-core,
  xorg,
  gtk3,
  libxkbcommon,
  nspr,
  libdrm,
  nss,
  mesa,
  alsa-lib,
}:
let
  package_name = "escrcpy";
  package_type = "deb";
  package_version = "1.18.2";
  github_release_tag = "v${package_version}";
  github_url = "https://github.com/viarotel-org/escrcpy";
  package_description = "Graphical Scrcpy to display and control Android, devices powered by Electron. ";
  srcs = {
    x86_64-linux = fetchurl {
      url = "${github_url}/releases/download/${github_release_tag}/Escrcpy-${package_version}-linux-amd64.deb";
      hash = "sha256-uNedoxEfiubxIIs9IgXvV90ns61PY1b6At65Qh0NcfM=";
    };
    aarch64-linux = fetchurl {
      url = "${github_url}/releases/download/${github_release_tag}/Escrcpy-${package_version}-linux-arm64.deb";
      hash = "";
    };
  };
  src =
    srcs.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "${package_name}_${package_type}";
  version = package_version;
  inherit src;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    dpkg
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    at-spi2-core
    libxkbcommon
    xorg.libXrandr
    xorg.libXfixes
    gtk3
    xorg.libXcomposite
    xorg.libXdamage
    libdrm
    nspr
    nss
    alsa-lib
    mesa
  ];
  runtimeDependencies = map lib.getLib [ ];
  installPhase = ''
    runHook preInstall
    _install() {
    mkdir -p $out/bin
    cp -r opt $out/opt
    cp -r usr/share $out/share
    substituteInPlace $out/share/applications/escrcpy.desktop --replace "/opt/Escrcpy/escrcpy" "$out/bin/escrcpy"
    makeWrapper $out/opt/Escrcpy/escrcpy $out/bin/escrcpy \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libGL ]}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
    }
    _install
    runHook postInstall
  '';

  meta = with lib; {
    homepage = github_url;
    description = package_description;
    # license = licenses.apache;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    # maintainers = with maintainers; [ Program-Learning ];
    broken = true;
  };
}
