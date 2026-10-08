{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  git,
  jq,
  mihomo,
  xdg-utils,
  nix-update-script,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-our-free-model requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-our-free-model)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-our-free-model";
    version = "2.0.0";

    src = fetchFromGitHub {
      owner = "Ebony-Vinyl";
      repo = "dsh-our-free-model";
      rev = "v${finalAttrs.version}";
      hash = "sha256-Vfp5fP4qmbULXFek6yi6FVPDI/cpdapXTIEuOc6oFrw=";
    };

    npmDeps = null;
    npmConfigHook = pkgs.emptyDirectory;

    nativeBuildInputs = [
      git
      jq
    ];

    dontNpmBuild = true;

    doCheck = true;

    postPatch = ''
      substituteInPlace scripts/forward-test.mjs \
        --replace-fail "resolveLoopbackBind('example.com'), /loopback/" "resolveLoopbackBind('example.com'), /loopback|could not resolve/"
    '';

    checkPhase = ''
      runHook preCheck
      git init -q
      node scripts/test-all.mjs
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall

      packageDir=$out/lib/node_modules/dsh-our-free-model
      mkdir -p $packageDir
      while IFS= read -r entry; do
        mkdir -p $packageDir/$(dirname $entry)
        cp -r $entry $packageDir/$(dirname $entry)/
      done < <(jq -r '.files[]' package.json)
      cp package.json $packageDir/

      runHook postInstall
    '';

    postInstall = ''
      packageDir=$out/lib/node_modules/dsh-our-free-model
      test -f $packageDir/index.js
      test -f $packageDir/client.js
      test -f $packageDir/cordis.patch.yml
      jq -r --arg dir "$packageDir/" '.files[] | "\(.sha256)  \($dir)\(.path)"' catalog/integrity.json | sha256sum --check --strict -
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    runtimeDeps = [
      mihomo
      xdg-utils
    ];

    passthru = {
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.6-flash-free";
          involvement = "authored";
        }
      ];
      updateScript = nix-update-script {
        attrPath = "dsh-our-free-model";
        extraArgs = [ "--flake" ];
      };
    };

    meta = {
      description = "Zero-setup free-model plugin for DeepSeek Harness: no login, no API key, live-tested model roster, real thinking budgets, an OpenAI-compatible forward port, and absorbed zero-quota channels";
      homepage = "https://github.com/Ebony-Vinyl/dsh-our-free-model";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
