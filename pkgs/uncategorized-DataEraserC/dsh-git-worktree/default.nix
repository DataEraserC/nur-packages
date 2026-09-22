{
  lib,
  pkgs,
  stdenv,
  inputs ? null,
  fetchurl,
}:
let
  dshPkgs = if inputs != null then pkgs.extend inputs.deepseek-harness.overlays.default else null;
  version = "0.9.2";
  src = fetchurl {
    url = "https://registry.npmjs.org/dsh-git-worktree/-/dsh-git-worktree-${version}.tgz";
    hash = "sha256-PhsyQW7tb/P03pbPfodHuazAgs4BSOdNJ7ee53SfzgM==";
  };
in
if dshPkgs == null then
  stdenv.mkDerivation {
    pname = "dsh-git-worktree";
    inherit version src;
    dontUnpack = true;
    buildPhase = "echo 'ERROR: dsh-git-worktree requires the deepseek-harness flake input. Use: nix build .#dsh-git-worktree' && exit 1";
    installPhase = "true";
    passthru.updateScript = [ (toString ./update.sh) ];
  }
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-git-worktree";
    inherit version src;

    npmDepsHash = "sha256-EySjNrUvF/TieWPHK4tCFIiGcOXDCUnskgGmzevPKU4=";

    npmFlags = [ "--legacy-peer-deps" ];

    dontNpmBuild = true;

    postPatch = ''
      cp ${./package.json} package.json
      cp ${./package-lock.json} package-lock.json
    '';

    installPhase = ''
      runHook preInstall

      npmInstallHook

      mkdir -p $out/lib/node_modules/dsh-git-worktree
      for item in *; do
        [ "$item" = "node_modules" ] && continue
        cp -r "$item" $out/lib/node_modules/dsh-git-worktree/
      done

      runHook postInstall
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-git-worktree/lib/index.js
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.5-free";
          involvement = "authored";
        }
      ];
      updateScript = [ (toString ./update.sh) ];
    };

    meta = {
      description = "Git worktree Session Targets for DeepSeek Harness with isolated task sessions, reversible local preview, human-confirmed delivery, recovery, and same-session iteration";
      homepage = "https://github.com/wloops/dsh-git-worktree";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
