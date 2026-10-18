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
  throw "dsh-git-worktree requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-git-worktree)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-git-worktree";
    version = "0.11.0";

    src = fetchurl {
      url = "https://registry.npmjs.org/dsh-git-worktree/-/dsh-git-worktree-${finalAttrs.version}.tgz";
      hash = "sha256-n6w1pLCSIes9xoBrvJodUC8+cvZ7uM5LhekVBOg1who=";
    };

    npmDepsHash = "sha256-P0UcKNZJccr9/ek1eACmh58U0Gl5ov+9TPH8x5m6XMs=";

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
        {
          agent = "dsh";
          model = "mimo-v2.6-flash-free";
          involvement = "assisted";
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
