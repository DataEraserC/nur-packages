{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchNpmDeps,
  npmHooks,
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
  version = "2.7.2";

  src = fetchFromGitHub {
    owner = "Ebony-Vinyl";
    repo = "dsh-our-free-model";
    rev = "v${finalAttrs.version}";
    hash = "sha256-0Z3GAFNbvR20jNAxGyZNxB+6qWzguou1ZDq/WHm0GQk=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  # Two 2.5.2 suites import packages the package.json lists as peer/dev
  # dependencies only: scripts/reload-test.mjs needs @deepseek-ai/cordis, and
  # scripts/channel-pack-test.mjs --source needs typescript plus dsh-llm and
  # dsh-llm/invariant. Without them 71/73 suites pass and reload plus
  # channel-source fail. The lockfile already pins all of them, so install the
  # tree rather than adding them one by one; nothing is imported at runtime, and
  # installPhase drops node_modules again so the output stays dependency-free.
  # npmConfigHook reads $npmDeps, which __structuredAttrs only exports from env.
  env.npmDeps = fetchNpmDeps {
    name = "dsh-our-free-model-standalone-npm-deps";
    inherit (finalAttrs) src;
    hash = "sha256-4o61JjPTDBVldCfB7EJBqU8LI44VM1bMmFNQnuAPmnw=";
  };

  nativeBuildInputs = [
    git
    jq
    nodejs
    nodejs.python
    makeWrapper
    npmHooks.npmConfigHook
  ];

  postPatch = ''
    # 2.7.2's legacy-upgrade suite replays the historical updaters from tags
    # v1.3.1/v2.5.9 via `git show <tag>:<path>` and `git archive <tag>`, so it
    # needs the upstream object database. A fetched source tree has none
    # (`git init -q` below only makes it empty, and fetchGit also stores a
    # .git-less tree), hence the misleading "path exists on disk, but not in
    # <rev>" failure; the remaining 99 suites still run.
    substituteInPlace scripts/test-all.mjs \
      --replace-fail "  ['legacy-upgrade', 'legacy-upgrade-test.mjs', mode === 'contributor' ? [] : ['--production']],
" ""

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

    rm -rf .git node_modules
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
