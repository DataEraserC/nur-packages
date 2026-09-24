{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  xdg-utils,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-oauthpro requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-oauthpro)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-oauthpro";
    version = "0.1.6";

    src = fetchFromGitHub {
      owner = "meyaomiao";
      repo = "dsh-oauthpro";
      tag = "v${finalAttrs.version}";
      hash = "sha256-9ICi59Pp7y95Dmo7iuK65+hf7VnvLPF2IgaLOFsRwUM=";
    };

    npmDepsHash = "sha256-0Z/v3/dWkCRrMC39h6xHeEB1iyJiE33qJ7Yclya1VXk=";

    postPatch = ''
      cp ${./package.json} package.json
      cp ${./package-lock.json} package-lock.json
      chmod u+w package.json package-lock.json
    '';

    doCheck = true;

    checkPhase = ''
      runHook preCheck
      node --test
      runHook postCheck
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-oauthpro/packages/dsh-plugin/lib/client.js
      test -f $out/lib/node_modules/dsh-oauthpro/packages/dsh-plugin/dist/index.mjs
      test -f $out/lib/node_modules/dsh-oauthpro/packages/dsh-plugin/cordis.patch.yml
    '';

    runtimeDeps = [ xdg-utils ];

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

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
      changelog = "https://github.com/meyaomiao/dsh-oauthpro/releases";
      description = "Provider account pool and quota plugin for DeepSeek Harness with live model catalog, balance and quota display";
      homepage = "https://github.com/meyaomiao/dsh-oauthpro";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
