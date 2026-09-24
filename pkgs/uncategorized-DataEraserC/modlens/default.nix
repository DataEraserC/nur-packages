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
  throw "modlens requires the deepseek-harness flake input; evaluate it through the flake (nix build .#modlens)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "modlens";
    version = "3.26.5";

    src = fetchurl {
      url = "https://registry.npmjs.org/@liustack/modlens/-/modlens-${finalAttrs.version}.tgz";
      hash = "sha256-u4fRodC4qhz2INqd8S10LyNdU9emo+IeZe2DUq7VB2I=";
    };

    npmDepsHash = "sha256-3M/YWzvfAddQk749BmogL+oIaIRhr8KmyFE8q4gAjlY=";

    dontNpmBuild = true;

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
      chmod u+w package-lock.json
    '';

    postInstall = ''
      modlensRoot=$out/lib/node_modules/@liustack/modlens
      test -f $modlensRoot/dsh/index.js
      test -f $modlensRoot/dsh/client.js
      test -f $modlensRoot/dist/main.js
    '';

    postFixup = ''
      modlensRoot=$out/lib/node_modules/@liustack/modlens
      test ! -L $modlensRoot/node_modules/commander
      test ! -L $modlensRoot/node_modules/undici
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;
    linkKernelNodeModulesKeep = [
      "commander"
      "undici"
    ];

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
      changelog = "https://github.com/liustack/modlens/blob/main/CHANGELOG.md";
      description = "Vision plugin for DeepSeek Harness that turns pasted images into structured JSON evidence through pluggable vision engines";
      homepage = "https://github.com/liustack/modlens";
      license = lib.licenses.mit;
      mainProgram = "modlens";
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
