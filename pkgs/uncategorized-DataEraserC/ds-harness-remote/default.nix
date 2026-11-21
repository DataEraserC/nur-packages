{
  lib,
  pkgs,
  inputs ? null,
  fetchurl,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "ds-harness-remote requires the deepseek-harness flake input; evaluate it through the flake (nix build .#ds-harness-remote)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "ds-harness-remote";
    version = "0.6.7";

    # Published npm tarball, immutable per version. The GitHub repository is a
    # pnpm monorepo whose HEAD (and README-pinned 0.6.5) drifts independently of
    # the released plugin; pin the tarball so the bundle is reproducible.
    src = fetchurl {
      url = "https://registry.npmjs.org/ds-harness-remote/-/ds-harness-remote-${finalAttrs.version}.tgz";
      hash = "sha256-WgB2Dxn5roBpMJ3Uc+8X0Kj4dWzIgsY+5JQvdoFCtwA=";
    };

    # Generated from the tarball's package.json with
    # `npm install --legacy-peer-deps --ignore-scripts` after removing its
    # monorepo-only workspace:* devDependencies.
    npmDepsHash = "sha256-KOjrjNysvxFXW+yjudUWj98lsuITKMQ6goHhAnAlOVc=";

    npmFlags = [
      "--legacy-peer-deps"
      "--ignore-scripts"
    ];

    dontNpmBuild = true;

    postPatch = ''
      cp ${./package.json} package.json
      cp ${./package-lock.json} package-lock.json
    '';

    installPhase = ''
      runHook preInstall

      npmInstallHook

      mkdir -p $out/lib/node_modules/ds-harness-remote
      for item in *; do
        [ "$item" = "node_modules" ] && continue
        cp -r "$item" $out/lib/node_modules/ds-harness-remote/
      done

      runHook postInstall
    '';

    postInstall = ''
      test -f $out/lib/node_modules/ds-harness-remote/dist/index.js
      test -f $out/lib/node_modules/ds-harness-remote/dist/client.js
      test -f $out/lib/node_modules/ds-harness-remote/cordis.patch.yml
      test -f $out/lib/node_modules/ds-harness-remote/dsh-plugin.json
    '';

    installation = dshPkgs.dsh.dsh-runtime;

    passthru = {
      # The plugin injects React components into the web UI; the Host entry
      # still runs headless for an Android dsh-Go client.
      requiresWeb = true;
      aiProvenance = [
        {
          agent = "CodeBuddy Code";
          model = "Hy4 flash (hy4flash-free)";
          involvement = "authored";
        }
      ];
      updateScript = [ (toString ./update.sh) ];
    };

    meta = {
      description = "End-to-end encrypted remote access to DeepSeek Harness workspaces from web and mobile clients";
      homepage = "https://github.com/liguobao/ds-harness-remote";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
