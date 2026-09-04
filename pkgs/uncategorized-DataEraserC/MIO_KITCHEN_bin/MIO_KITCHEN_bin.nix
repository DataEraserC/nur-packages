{
  fetchzip,
  lib,
  stdenvNoCC,
  zlib,
  stdenv,
  libx11,
  libxcursor,
  libxcb,
  libxau,
  libxdmcp,
  autoPatchelfHook,
}:
let
  version = "4.2.1";
  releaseTag = "CI_BUILD_524";
  repo = "https://github.com/ColdWindScholar/MIO-KITCHEN-SOURCE";
  libpath = lib.makeLibraryPath [
    libxcb
    libx11
    libxcursor
    libxau
    libxdmcp
  ];
in
stdenvNoCC.mkDerivation {
  pname = "MIO_KITCHEN_bin";
  inherit version;

  src = fetchzip {
    url = "${repo}/releases/download/${releaseTag}/MIO-KITCHEN-${version}-linux.zip";
    hash = "sha256-NXBuN55NydYB0stmqNYosxEXuYBPxk7VyMSMA+/Nd+E=";
    stripRoot = false;
  };

  passthru.updateScript = [ (toString ./update.sh) ];

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    zlib
    stdenv.cc.cc.lib
    libx11
    libxcursor
    libxcb
    libxau
    libxdmcp
  ];

  installPhase = ''
            runHook preInstall
            _install() {
              mkdir -p $out/{bin,opt/MIO-KITCHEN}
              cp -r $src/* $out/opt/MIO-KITCHEN
              chmod -R a+rX $out/opt/MIO-KITCHEN
              chmod +x $out/opt/MIO-KITCHEN/tool

              cat > $out/bin/MIO-KITCHEN <<'EOS'
              #!/bin/bash
              set -e
              base="$(cd "$(dirname "$0")/.." && pwd)"
              appdir="''${MIO_KITCHEN_DATA:-''${XDG_DATA_HOME:-$HOME/.local/share}/MIO-KITCHEN}"
              export LD_LIBRARY_PATH="@LIBPATH@''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              if [ ! -x "$appdir/tool" ]; then
                rm -rf "$appdir"
                mkdir -p "$appdir"
                cp -r "$base/opt/MIO-KITCHEN/." "$appdir/"
                chmod -R u+w "$appdir"
              fi
              cd "$appdir"
              exec "$appdir/tool" "$@"
    EOS
          chmod +x $out/bin/MIO-KITCHEN
          sed -i 's|^[[:space:]]*||' $out/bin/MIO-KITCHEN
          sed -i "s|@LIBPATH@|${libpath}|" $out/bin/MIO-KITCHEN
            }
            _install
            runHook postInstall
  '';

  meta = {
    description = "Android ROM tooling suite";
    homepage = repo;
    platforms = [ "x86_64-linux" ];
    mainProgram = "MIO-KITCHEN";
  };
}
