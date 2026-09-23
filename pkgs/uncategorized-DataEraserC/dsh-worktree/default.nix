{
  lib,
  pkgs,
  inputs ? null,
  fetchurl,
  git,
  jq,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-worktree requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-worktree)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-worktree";
    version = "0.1.0";

    src = fetchurl {
      url = "https://registry.npmjs.org/dsh-worktree/-/dsh-worktree-${finalAttrs.version}.tgz";
      hash = "sha256-fWXmetQ4WeCuAQ7Tngw1JlVAeVB/4jD8iicG9Eaey4U=";
    };

    npmDepsHash = "sha256-ttKFjT5c9mqm82aKnPSNLJPyp7lEdT3VZtPJUpyLYBE=";

    npmFlags = [ "--legacy-peer-deps" ];

    dontNpmBuild = true;
    nativeBuildInputs = [ jq ];

    postPatch = ''
      cp ${./package.json} package.json
      cp ${./package-lock.json} package-lock.json
      cp ${./cordis.patch.yml} cordis.patch.yml
      chmod u+w package.json package-lock.json cordis.patch.yml
      jq '.dsh.bundle.patch = "./cordis.patch.yml" | .files = ((.files // []) + ["cordis.patch.yml"])' package.json > package.json.tmp
      mv package.json.tmp package.json
    '';

    installPhase = ''
      runHook preInstall

      npmInstallHook

      mkdir -p $out/lib/node_modules/dsh-worktree
      for item in *; do
        [ "$item" = "node_modules" ] && continue
        cp -r "$item" $out/lib/node_modules/dsh-worktree/
      done

      runHook postInstall
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-worktree/lib/index.js
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;
    runtimeDeps = [ git ];

    passthru = {
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.6-flash-free";
          involvement = "authored";
        }
      ];
      updateScript = [ (toString ./update.sh) ];
    };

    meta = {
      description = "Codex-style permanent git worktrees for DeepSeek Harness: agent tools, a /worktree command, and session context for durable worktrees";
      homepage = "https://github.com/FlashingChen/dsh-worktree";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
