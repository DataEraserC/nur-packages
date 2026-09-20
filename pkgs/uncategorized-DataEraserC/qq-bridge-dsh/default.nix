{
  lib,
  stdenv,
  pkgs,
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

  # Patched unwrapped: copy the full package tree, patch ROOT in MCP servers
  # so they read config from $QQ_BRIDGE_HOME instead of the read-only store.
  patchedUnwrapped = unwrapped.overrideAttrs (old: {
    pname = "${old.pname}-patched";
    postInstall = (old.postInstall or "") + ''
      srcDir="$out/lib/node_modules/qq-bridge/src"
      chmod -R u+w "$srcDir"
      for f in mcp-snowluma-safe.js mcp-host-server.js; do
        substituteInPlace "$srcDir/$f" \
          --replace 'const ROOT = path.resolve(__dirname, '"'"'..'"'"');' \
                    'const ROOT = process.env.QQ_BRIDGE_HOME || path.resolve(__dirname, '"'"'..'"'"');'
      done
    '';
  });
  patchedSrc = "${patchedUnwrapped}/lib/node_modules/qq-bridge";
in
stdenv.mkDerivation {
  pname = "qq-bridge-dsh";
  inherit version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    pkgDir=$out/lib/node_modules/qq-bridge-dsh
    mkdir -p $pkgDir

    # ── Full patched package (src + node_modules + all dependencies) ──
    cp -r ${patchedSrc}/* $pkgDir/

    # ── DSH bundle package.json (must override unwrapped's) ──
    cp ${./package.json} $pkgDir/package.json
    substituteInPlace $pkgDir/package.json \
      --replace '@VERSION@' '${version}'

    # ── cordis.patch.yml: substitute paths ──
    cp ${./cordis.patch.yml} $pkgDir/cordis.patch.yml
    substituteInPlace $pkgDir/cordis.patch.yml \
      --replace '@NODE@' '${node}' \
      --replace '@PKGDIR@' "$pkgDir" \
      --replace '@QQ_BRIDGE_HOME@' '${qqBridgeHome}'

    # ── Preset files ──
    presetDir=$out/share/qq-bridge-presets
    mkdir -p $presetDir
    cp -r ${patchedSrc}/dsh/agent-presets/* $presetDir/

    # ── qq-mode-console plugin ──
    pluginDir=$pkgDir/plugins/qq-mode-console
    mkdir -p $pluginDir
    cp -r ${patchedSrc}/plugins/qq-mode-console/* $pluginDir/

    # ── DSH bundle metadata ──
    mkdir -p $out/nix-support
    substitute ${./dsh-bundles.json} $out/nix-support/dsh-bundles.json \
      --replace '@VERSION@' '${version}' \
      --replace '@PKGDIR@' "$pkgDir"

    runHook postInstall
  '';

  passthru = {
    inherit unwrapped patchedUnwrapped qqBridgeHome;
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
