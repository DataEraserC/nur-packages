{
  lib,
  stdenv,
  pkgs,
  inputs ? null,
  runCommand,
  nodejs,
  nix-update-script,
}:

let
  unwrapped = pkgs.callPackage ../qq-bridge-unwrapped { };
  inherit (unwrapped) version;
  node = "${nodejs}/bin/node";
  src = "${unwrapped}/lib/node_modules/qq-bridge";
  bundleSrc = runCommand "qq-bridge-dsh-src" { } ''
    mkdir -p $out
    substitute ${./package.json} $out/package.json --replace '@VERSION@' '${version}'
    substitute ${./cordis.patch.yml} $out/cordis.patch.yml \
      --replace '@NODE@' '${node}' \
      --replace '@SRC@' '${src}'
    substitute ${./dsh-bundles.json} $out/dsh-bundles.json \
      --replace '@VERSION@' '${version}'
  '';
in
if inputs == null then
  throw "qq-bridge-dsh requires the deepseek-harness flake input; evaluate it through the flake (nix build .#qq-bridge-dsh)"
else
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
      cp $src/cordis.patch.yml $pkgDir/

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
      inherit unwrapped;
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
