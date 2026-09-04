# Taken from https://github.com/NixOS/nixpkgs/commit/cc0ac2c9d43886a16ef637e9b4811f961e0186d7#diff-10c2d2e2e6f7a758d0843dc7028d43c9b535b9bdb871e2ceff0d17e004c110cb
# to be able to override `src`
{
  stdenv,
  lib,
  alsa-lib,
  autoPatchelfHook,
  buildFHSEnvBubblewrap,
  copyDesktopItems,
  dbus,
  dpkg,
  expat,
  fontconfig,
  glib,
  libdrm,
  libglvnd,
  libpulseaudio,
  libudev0-shim,
  libxkbcommon,
  libxml2,
  libxslt,
  outils,
  makeDesktopItem,
  makeWrapper,
  nspr,
  nss,
  wayland,
  patchelf,
  fetchurl,
  xorg,
}:

let
  version = "8.2.2";

  ptFiles = stdenv.mkDerivation {
    name = "PacketTracer8Drv";
    inherit version;

    dontUnpack = true;
    src = fetchurl {
      url = "https://github.com/DataEraserC/nur-packages/releases/download/CiscoPacketTracer822_amd64_signed.deb/CiscoPacketTracer822_amd64_signed.deb";
      sha256 = "sha256-bNK4iR35LSyti2/cR0gPwIneCFxPP+leuA1UUKKn9y0=";
    };

    nativeBuildInputs = [
      alsa-lib
      autoPatchelfHook
      patchelf
      dbus
      dpkg
      expat
      fontconfig
      glib
      libdrm
      libglvnd
      libpulseaudio
      libudev0-shim
      libxkbcommon
      libxml2
      libxslt
      makeWrapper
      nspr
      nss
      wayland
    ]
    ++ (with xorg; [
      libICE
      libSM
      libX11
      libxcb
      libXcomposite
      libXcursor
      libXdamage
      libXext
      libXfixes
      libXi
      libXrandr
      libXrender
      libXScrnSaver
      libXtst
      xcbutilimage
      xcbutilkeysyms
      xcbutilrenderutil
      xcbutilwm
    ]);

    buildInputs = [
      libxml2.out
    ];

    runtimeDependencies = [
      libxml2.out
    ];

    autoPatchelfIgnoreMissingDeps = [
      "libxml2.so.2"
    ];

    installPhase = ''
      dpkg-deb -x $src $out
      chmod 755 "$out"
      makeWrapper "$out/opt/pt/bin/PacketTracer" "$out/bin/packettracer" \
        --prefix LD_LIBRARY_PATH : "${libxml2.out}/lib:$out/opt/pt/bin"
      # Keep source archive cached, to avoid re-downloading
      ln -s $src $out/usr/share/
    '';
  };

  desktopItem = makeDesktopItem {
    name = "cisco-pt8.desktop";
    desktopName = "Cisco Packet Tracer 8";
    icon = "${ptFiles}/opt/pt/art/app.png";
    exec = "packettracer8 %f";
    mimeTypes = [
      "application/x-pkt"
      "application/x-pka"
      "application/x-pkz"
    ];
  };

  fhs = buildFHSEnvBubblewrap {
    name = "packettracer8";
    runScript = "${ptFiles}/bin/packettracer";
    targetPkgs = _pkgs: [
      libudev0-shim
      libxml2.out
    ];

    extraInstallCommands = ''
      mkdir -p "$out/share/applications"
      cp "${desktopItem}"/share/applications/* "$out/share/applications/"
    '';
  };
in
stdenv.mkDerivation {
  pname = "ciscoPacketTracer8";
  inherit version;

  dontUnpack = true;

  installPhase = ''
    mkdir $out
    ${outils}/bin/lndir -silent ${fhs} $out
  '';

  desktopItems = [ desktopItem ];
  nativeBuildInputs = [ copyDesktopItems ];

  meta = with lib; {
    description = "Network simulation tool from Cisco";
    homepage = "https://www.netacad.com/courses/packet-tracer";
    license = licenses.unfree;
    mainProgram = "packettracer8";
    maintainers = with maintainers; [ lucasew ];
    platforms = [ "x86_64-linux" ];
    # The bundled QtWebEngine links against the legacy libxml2.so.2 ABI
    # (versioned symbols like LIBXML2_2.4.30), which modern nixpkgs no
    # longer provides; it builds but cannot start.
    broken = true;
  };
}
