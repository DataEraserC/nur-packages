{
  stdenv,
  p7zip,
  runtimeShell,
  wineWow64Packages,
  sources,
  lib,
}:
let
  wine = wineWow64Packages.waylandFull;
in
stdenv.mkDerivation rec {
  inherit (sources.alipan) pname src;
  # inherit (sources.alipan-version) version;
  inherit (sources.alipan) version;
  nativeBuildInputs = [
    p7zip
    wine
  ];
  unpackPhase = ''
    runHook preUnpack
    # Method 2 Step 1: Install when evaling
    7z x $src
    runHook postUnpack
  '';
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    mkdir -p "$out/lib/aDrive"
    cp -r ./* "$out/lib/aDrive"

    cat << 'EOF' > "$out/bin/aDrive"
    #!${runtimeShell}
    export PATH=${wine}/bin:$PATH
    export WINEDLLOVERRIDES="mscoree=" # disable mono

    # Solves PermissionError: [Errno 13] Permission denied: '/homeless-shelter/.wine'
    # export HOME=$(mktemp -d)

    export WINEPREFIX="''${ALIPAN_HOME:-"''${XDG_DATA_HOME:-"''${HOME}/.local/share"}/alipan"}/wine"

    if [ ! -d "$WINEPREFIX" ] ; then
      mkdir -p "$WINEPREFIX"

      # Method 1 Step 1: Install when running
      # wine ${src} /S

    fi

    wineInputFile=$(${wine}/bin/wine winepath -w $1)

    # Method 1 Step 2: running on not const path
    # ${wine}/bin/wine "$WINEPREFIX/drive_c/users/nixos/AppData/Local/Programs/aDrive/aDrive.exe" "$wineInputFile"

    # Method 2 Step 2: running on const path
    ${wine}/bin/wine "$out/lib/aDrive/aDrive.exe" "$wineInputFile"
    EOF

    substituteInPlace $out/bin/aDrive \
      --replace "\$out" "$out"

    chmod +x "$out/bin/aDrive"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Aliyun aDrive";
    homepage = "https://www.alipan.com/";
    license = licenses.unfreeRedistributable;
    maintainers = [ ];
    inherit (wine.meta) platforms;
    mainProgram = "aDrive";
  };
}
