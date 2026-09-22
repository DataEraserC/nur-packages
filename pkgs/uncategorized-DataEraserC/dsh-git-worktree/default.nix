{
  lib,
  pkgs,
  inputs ? null,
  fetchurl,
  nix-update-script,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-git-worktree requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-git-worktree)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-git-worktree";
    version = "0.9.2";

    src = fetchurl {
      url = "https://registry.npmjs.org/dsh-git-worktree/-/dsh-git-worktree-${finalAttrs.version}.tgz";
      hash = "sha256-PhsyQW7tb/P03pbPfodHuazAgs4BSOdNJ7ee53SfzgM==";
    };

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
      updateScript = nix-update-script {
        attrPath = "dsh-git-worktree";
        extraArgs = [ "--flake" ];
      };
    };

    meta = {
      description = "Git worktree Session Targets for DeepSeek Harness with isolated task sessions, reversible local preview, human-confirmed delivery, recovery, and same-session iteration";
      homepage = "https://github.com/wloops/dsh-git-worktree";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
