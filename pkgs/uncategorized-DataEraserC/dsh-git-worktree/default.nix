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
    version = "0.12.4";

    src = fetchurl {
      url = "https://registry.npmjs.org/dsh-git-worktree/-/dsh-git-worktree-${finalAttrs.version}.tgz";
      hash = "sha256-uycR6N4EwIRJw4yyEExbhBWn5EW+Y1laMXUyCV6Bet4=";
    };

    npmDepsHash = "sha256-wKq+W+x3UkkYQTSd6jeqWhH9ye2fhcFxDws0KEFAUCg=";

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

    installation = dshPkgs.dsh.dsh-runtime;

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
