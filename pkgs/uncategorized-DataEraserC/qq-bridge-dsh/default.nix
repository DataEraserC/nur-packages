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
    cp ${./cordis.patch.yml} $out/cordis.patch.yml
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

      # Substitute store paths into cordis.patch.yml
      sed -e 's|REPLACE_NODE|${node}|g' \
          -e "s|REPLACE_SRC|${src}|g" \
          $src/cordis.patch.yml > $pkgDir/cordis.patch.yml

      # ── Preset files ──
      presetDir=$out/share/qq-bridge-presets
      mkdir -p $presetDir
      cp -r ${src}/dsh/agent-presets/* $presetDir/

      # ── qq-mode-console plugin ──
      pluginDir=$pkgDir/plugins/qq-mode-console
      mkdir -p $pluginDir
      cp -r ${src}/plugins/qq-mode-console/* $pluginDir/

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
