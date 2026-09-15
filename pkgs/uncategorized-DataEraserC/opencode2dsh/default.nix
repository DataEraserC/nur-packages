{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchPnpmDeps,
  jq,
  pnpm_10,
  pnpmConfigHook,
  nodejs_24,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode2dsh";
  version = "0.3.1";
  src = fetchFromGitHub {
    owner = "FishBottle7";
    repo = "opencode2dsh";
    rev = "v${finalAttrs.version}";
    hash = "sha256-IdSV3pSC2XT4nGM8bZo9ffQQxADhtf4VjcLbzI/POOs=";
  };

  pnpmDeps = fetchPnpmDeps {
    pname = "opencode2dsh";
    inherit (finalAttrs) version src;
    pnpm = pnpm_10;
    fetcherVersion = 4;
    sourceRoot = "source/packages/plugin";
    hash = "sha256-CLwdlmllYnTb/Qg+xvcEkfKbPt9jGcsusa9NZK2qKDM=";
  };

  nativeBuildInputs = [
    jq
    nodejs_24
    pnpm_10
    pnpmConfigHook
  ];

  pnpmRoot = "packages/plugin";

  preConfigure = ''
    echo 'node-linker=hoisted' > .npmrc
  '';

  buildPhase = ''
    runHook preBuild
    cd packages/plugin
    pnpm build
    cd ../..
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/node_modules/@opencode2dsh/dsh-plugin
    cp -r packages/plugin/node_modules $out/lib/node_modules/@opencode2dsh/dsh-plugin/
    cp -r packages/plugin/lib $out/lib/node_modules/@opencode2dsh/dsh-plugin/
    cp packages/plugin/cordis.patch.yml $out/lib/node_modules/@opencode2dsh/dsh-plugin/
    cp packages/plugin/package.json $out/lib/node_modules/@opencode2dsh/dsh-plugin/
    jq '.dsh = {"bundle": {"patch": "./cordis.patch.yml"}}' \
      $out/lib/node_modules/@opencode2dsh/dsh-plugin/package.json > package.json.tmp
    mv package.json.tmp $out/lib/node_modules/@opencode2dsh/dsh-plugin/package.json
    mkdir -p $out/nix-support
    cat > $out/nix-support/dsh-bundles.json << EOF
    {
      "schema": 1,
      "bundles": [
        {
          "name": "@opencode2dsh/dsh-plugin",
          "version": "${finalAttrs.version}",
          "patch": "./cordis.patch.yml",
          "packageRoot": "$out/lib/node_modules/@opencode2dsh/dsh-plugin"
        }
      ]
    }
    EOF
    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script { };
    dshBundle = true;
    dshBundleHelper = "buildDshBundle";
    runtimeDeps = [ ];
  };

  meta = {
    changelog = "https://github.com/FishBottle7/opencode2dsh/blob/master/CHANGELOG.md";
    description = "DSH plugin for free OpenCode Zen models with native adapter and no API key";
    homepage = "https://github.com/FishBottle7/opencode2dsh";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ DataEraserC ];
    platforms = lib.platforms.unix;
  };
})
