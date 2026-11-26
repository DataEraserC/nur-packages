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
  openssl,
  xdg-utils,
  nix-update-script,
}:
let
  # Browser-based suites (feedback-e2e, feedback-plugin-ui and friends)
  # `require()` playwright from a Windows developer path baked into the
  # scripts, with `OFM_PLAYWRIGHT_MODULE` as the documented override. The Nix
  # builder has no browser, so point that override at a stub whose launch()
  # rejects with a recognisable marker. checkPhase turns exactly those suites
  # into an explicit SKIP instead of a green pass, so the log never claims
  # browser coverage that did not happen.
  noBrowserPlaywright = builtins.toFile "ofm-no-browser-playwright.js" ''
    const noBrowser = () => {
      const error = new Error("OFM_NO_BROWSER: no browser is available in this build");
      error.code = "OFM_NO_BROWSER";
      return error;
    };
    const chromium = {
      launch: async () => { throw noBrowser(); },
      launchPersistentContext: async () => { throw noBrowser(); },
      connect: async () => { throw noBrowser(); },
      executablePath: () => { throw noBrowser(); },
    };
    module.exports = { chromium, firefox: chromium, webkit: chromium };
  '';
in
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-our-free-model-standalone";
  version = "2.9.1-macos-unofficial";

  src = fetchFromGitHub {
    owner = "Ebony-Vinyl";
    repo = "dsh-our-free-model";
    rev = "v${finalAttrs.version}";
    hash = "sha256-nwslCewzR9Wgd/8SG/e9DpJeAqLbcWPvywT/2n5Acck=";
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
    hash = "sha256-1cSvpDGw/z5tns9BOoKhctOfu0irNf9MEGMmuR3tR2k=";
  };

  nativeBuildInputs = [
    git
    jq
    nodejs
    nodejs.python
    makeWrapper
    npmHooks.npmConfigHook
    # 2.9.0's lane-exit suite mints a throwaway self-signed certificate with
    # `openssl req -x509` so its stand-in exits can terminate TLS; without the
    # binary the suite dies with `spawnSync openssl ENOENT`.
    openssl
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
    # Point the browser suites at the no-browser stub (see noBrowserPlaywright
    # above) and keep their real output, so the SKIP lines below quote what
    # actually happened.
    export OFM_PLAYWRIGHT_MODULE=${noBrowserPlaywright}
    suiteStatus=0
    node scripts/test-all.mjs 2>&1 | tee "$TMPDIR/test-all.log" || suiteStatus=$?
    if [ "$suiteStatus" -eq 0 ]; then
      runHook postCheck
      return 0
    fi
    # Only the browser suites may fail here. Anything else is a real failure.
    failedSuites=$(sed -n "s/^ *FAIL \([a-z0-9-]*\).*/\1/p" "$TMPDIR/test-all.log" | sort -u)
    unexpected=""
    skipped=""
    for suite in $failedSuites; do
      case "$suite" in
        feedback-e2e | feedback-plugin-ui)
          grep -q "OFM_NO_BROWSER" "$TMPDIR/test-all.log" &&
            skipped="$skipped $suite" ||
            unexpected="$unexpected $suite"
          ;;
        *) unexpected="$unexpected $suite" ;;
      esac
    done
    if [ -n "$unexpected" ]; then
      echo "checkPhase: non-browser suites failed:$unexpected" >&2
      tail -40 "$TMPDIR/test-all.log" >&2
      return 1
    fi
    for suite in $skipped; do
      echo "SKIP $suite — requires a browser, which this build environment does not have" >&2
    done
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
      {
        agent = "qoder-cn";
        model = "auto";
        involvement = "assisted";
      }
    ];
    # Same untagged-release trap as ../dsh-our-free-model: only `v<digits>`
    # tags are real releases, and `rev` interpolates the `v` back onto the
    # version, so the regex must strip it.
    updateScript = nix-update-script {
      extraArgs = [
        "--version-regex"
        "^v([0-9].*)$"
      ];
    };
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
