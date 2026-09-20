{
  lib,
  stdenv,
  pkgs,
  runCommand,
  nodejs,
  nix-update-script,
  # Runtime path to qq-bridge data directory (config.json, state/).
  # Override via: pkgs.qq-bridge-dsh.override { qqBridgeHome = "/custom/path"; }
  qqBridgeHome ? "~/.local/share/qq-bridge",
}:

let
  unwrapped = pkgs.callPackage ../qq-bridge-unwrapped { };
  inherit (unwrapped) version;
  node = "${nodejs}/bin/node";
  src = "${unwrapped}/lib/node_modules/qq-bridge";
  bundleSrc = runCommand "qq-bridge-dsh-src" { } ''
    mkdir -p $out

    # ── Patched source tree ──
    # MCP servers import sibling modules (./sensitive.js, ./safe-fetch.js, etc.),
    # so we copy the entire src/ directory and patch ROOT in-place.
    # In NixOS the store is read-only; ROOT falls back to $QQ_BRIDGE_HOME at runtime.
    cp -r ${src}/src $out/src
    chmod -R u+w $out/src
    for f in mcp-snowluma-safe.js mcp-host-server.js; do
      substituteInPlace $out/src/$f \
        --replace 'const ROOT = path.resolve(__dirname, '"'"'..'"'"');' \
                  'const ROOT = process.env.QQ_BRIDGE_HOME || path.resolve(__dirname, '"'"'..'"'"');'
    done

    substitute ${./package.json} $out/package.json --replace '@VERSION@' '${version}'
    substitute ${./dsh-bundles.json} $out/dsh-bundles.json \
      --replace '@VERSION@' '${version}'
  '';
in
stdenv.mkDerivation {
  pname = "qq-bridge-dsh";
  inherit version;

  src = bundleSrc;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    pkgDir=$out/lib/node_modules/qq-bridge-dsh
    mkdir -p $pkgDir

    cp $src/package.json $pkgDir/
    cp ${./cordis.patch.yml} $pkgDir/cordis.patch.yml
    substituteInPlace $pkgDir/cordis.patch.yml \
      --replace '@NODE@' '${node}' \
      --replace '@PKGDIR@' "$pkgDir" \
      --replace '@QQ_BRIDGE_HOME@' '${qqBridgeHome}'

    # ── Patched source tree (MCP servers + all sibling modules) ──
    cp -r $src/src $pkgDir/src

    # ── Preset files ──
    presetDir=$out/share/qq-bridge-presets
    mkdir -p $presetDir
    cp -r ${src}/dsh/agent-presets/* $presetDir/

    # ── qq-mode-console plugin ──
    pluginDir=$pkgDir/plugins/qq-mode-console
    mkdir -p $pluginDir
    cp -r ${src}/plugins/qq-mode-console/* $pluginDir/

    # ── DSH bundle metadata ──
    mkdir -p $out/nix-support
    substitute $src/dsh-bundles.json $out/nix-support/dsh-bundles.json \
      --replace '@PKGDIR@' "$pkgDir"

    runHook postInstall
  '';

  passthru = {
    inherit unwrapped qqBridgeHome;
    dshBundle = true;
    dshBundleHelper = "buildDshBundle";
    runtimeDeps = [ ];
    aiProvenance = [
      {
        agent = "dsh";
        model = "mimo-v2.5-free";
        involvement = "assisted";
      }
    ];
    updateScript = nix-update-script {
      attrPath = "qq-bridge-dsh";
      extraArgs = [ "--flake" ];
    };
  };

  meta = {
    description = "DSH bundle for qq-bridge: MCP servers and agent presets";
    homepage = "https://github.com/Derpyu520/qq-bridge";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.unix;
  };
}
