{
  lib,
  stdenv,
  pkgs,
  nodejs,
  coreutils,
}:

let
  unwrapped = pkgs.callPackage ../qq-bridge-unwrapped { };
in
stdenv.mkDerivation {
  pname = "qq-bridge";
  inherit (unwrapped) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cat > $out/bin/qq-bridge << 'WRAPPER'
    #! ${stdenv.shell}
    export PATH="${
      lib.makeBinPath [
        coreutils
        nodejs
      ]
    }:$PATH"

    # Config/data directory: QQ_BRIDGE_HOME > XDG_DATA_HOME > ~/.local/share
    QQ_BRIDGE_HOME="''${QQ_BRIDGE_HOME:-''${XDG_DATA_HOME:-$HOME/.local/share}/qq-bridge}"
    mkdir -p "$QQ_BRIDGE_HOME"

    # First run: copy entire package tree to writable location
    if [ ! -f "$QQ_BRIDGE_HOME/package.json" ]; then
      cp -r UNWRAPPED_PATH/lib/node_modules/qq-bridge/* "$QQ_BRIDGE_HOME/"
      chmod -R u+w "$QQ_BRIDGE_HOME"
    fi

    # Config: create from example if missing
    if [ ! -f "$QQ_BRIDGE_HOME/config.json" ] && [ -f "$QQ_BRIDGE_HOME/config.example.json" ]; then
      cp "$QQ_BRIDGE_HOME/config.example.json" "$QQ_BRIDGE_HOME/config.json"
    fi

    exec node "$QQ_BRIDGE_HOME/src/bridge.js" "$@"
    WRAPPER
    chmod +x $out/bin/qq-bridge

    substituteInPlace $out/bin/qq-bridge \
      --replace-quiet 'UNWRAPPED_PATH' '${unwrapped}'

    runHook postInstall
  '';

  passthru = {
    inherit unwrapped;
    aiProvenance = [
      {
        agent = "dsh";
        model = "mimo-v2.5-free";
        involvement = "assisted";
      }
    ];
  };

  meta = {
    description = "QQ (SnowLuma OneBot v11) bridge for DeepSeek Harness agents";
    homepage = "https://github.com/Derpyu520/qq-bridge";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.unix;
    mainProgram = "qq-bridge";
  };
}
