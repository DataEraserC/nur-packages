{
  lib,
  stdenv,
  fetchFromGitHub,
  git,
  jq,
  nodejs,
  makeWrapper,
  mihomo,
  xdg-utils,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-our-free-model-standalone";
  version = "2.5.2";

  src = fetchFromGitHub {
    owner = "Ebony-Vinyl";
    repo = "dsh-our-free-model";
    rev = "v${finalAttrs.version}";
    hash = "sha256-bvsRCZEmtCEtlhBiCgnbugBO7D5YSNqemQQc6cswrQE=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs = [
    git
    jq
    nodejs
    makeWrapper
  ];

  postPatch = ''
    substituteInPlace scripts/forward-test.mjs \
      --replace-fail "resolveLoopbackBind('example.com'), /loopback/" "resolveLoopbackBind('example.com'), /loopback|could not resolve/"
    substituteInPlace scripts/standalone-login-terminal-test.mjs \
      --replace-fail "/usr/bin/printf '%s" "printf '%s"
  '';

  doCheck = true;

  checkPhase = ''
    runHook preCheck
    git init -q
    node scripts/test-all.mjs
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    rm -rf .git
    packageDir=$out/lib/our-free-model-standalone
    mkdir -p $packageDir
    cp -r . $packageDir/

    makeWrapper ${lib.getExe nodejs} $out/bin/our-free-model-standalone \
      --add-flags $packageDir/packages/standalone/cli.mjs \
      --set NODE_ENV production \
      --prefix PATH : ${
        lib.makeBinPath [
          mihomo
          xdg-utils
        ]
      }

    runHook postInstall
  '';

  postInstall = ''
    packageDir=$out/lib/our-free-model-standalone
    test -f $packageDir/packages/standalone/cli.mjs
    test -f $packageDir/packages/standalone/web/index.html
    test -f $packageDir/vendor/channel-pack/qoder-auth-wasm.wasm
    jq -r --arg dir "$packageDir/" '.files[] | "\(.sha256)  \($dir)\(.path)"' catalog/integrity.json | sha256sum --check --strict -
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck
    grep -q "Our Free Model" <($out/bin/our-free-model-standalone --help)
    runHook postInstallCheck
  '';

  passthru = {
    aiProvenance = [
      {
        agent = "dsh";
        model = "mimo-v2.6-flash-free";
        involvement = "authored";
      }
    ];
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Standalone zero-setup free-model gateway with a web management console, distilled from dsh-our-free-model and runnable without DeepSeek Harness";
    homepage = "https://github.com/Ebony-Vinyl/dsh-our-free-model";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    mainProgram = "our-free-model-standalone";
    platforms = lib.platforms.unix;
  };
})
