{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-settings-persist requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-settings-persist)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-settings-persist";
    version = "0.3.2";

    src = fetchFromGitHub {
      owner = "DataEraserC";
      repo = "dsh-settings-persist";
      rev = "b75d81174a6b2b8b6fc3ff97ef6339cea1204b88";
      # nix-prefetch-url --unpack of the codeload tarball for the pinned rev.
      hash = "sha256-ZC04UesTSDXLnrVwQVfPjSDTSGKw/UfjByYw883xnoo=";
    };

    # Zero runtime dependencies: the lockfile has no cacheable entries, so
    # the empty dependency cache is intentional.
    npmDepsHash = "sha256-eGczmsD08bqFFHTiRSuJz5recGjZiKMRuOfA5nOQJ+k=";
    forceEmptyCache = true;

    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/dsh-settings-persist
      cp -r lib cordis.patch.yml package.json $out/lib/node_modules/dsh-settings-persist/

      runHook postInstall
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-settings-persist/lib/index.js
      test -f $out/lib/node_modules/dsh-settings-persist/lib/client.js
      test -f $out/lib/node_modules/dsh-settings-persist/cordis.patch.yml
    '';

    passthru = {
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.6-flash-free";
          involvement = "authored";
        }
      ];
    };

    meta = {
      description = "Persist DSH Settings edits across nix managed-profile syncs and rebuilds, with auto/manual snapshots and a settings page";
      homepage = "https://github.com/DataEraserC/dsh-settings-persist";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
