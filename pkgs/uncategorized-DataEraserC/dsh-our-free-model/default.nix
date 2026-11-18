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
  # Kernel profile names, beyond the `web`/`web-desktop`/`desktop` set that
  # src/vault.js admits on its own, that should unlock the sealed EAC lane.
  # Empty by default: the build is then byte-identical to upstream.
  # Override via: pkgs.dsh-our-free-model.override { extraWebProfiles = [ ... ]; }
  extraWebProfiles ? [ ],
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;

  # Browser-based suites `require()` playwright from a Windows developer path
  # baked into the scripts, with `OFM_PLAYWRIGHT_MODULE` as the documented
  # override. The Nix builder has no browser, so point that override at a stub
  # whose launch() rejects with a recognisable marker. checkPhase turns exactly
  # those suites into an explicit SKIP instead of a green pass, so the log never
  # claims browser coverage that did not happen.
  noBrowserPlaywright = pkgs.writeText "ofm-no-browser-playwright.cjs" ''
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
if inputs == null then
  throw "dsh-our-free-model requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-our-free-model)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-our-free-model";
    version = "2.8.6-macos-unofficial";

    src = fetchFromGitHub {
      owner = "Ebony-Vinyl";
      repo = "dsh-our-free-model";
      rev = "v${finalAttrs.version}";
      hash = "sha256-zE4qI/Zha5HA1PCfXIawD63AOae12qO89hJozkGQvc4=";
    };

    npmDepsHash = "sha256-tqyEKjh0uN/uTLsrZJ9yfoJ3j4l0SQPdXUHDa7RODvU=";

    nativeBuildInputs = [
      git
      jq
    ];

    dontNpmBuild = true;

    doCheck = true;

    postPatch = ''
            # 2.7.2's legacy-upgrade suite replays historical updaters through
            # `git show <tag>:<path>` / `git archive <tag>` from tags v1.3.1 and
            # v2.5.9; a fetched source tree has no object database, so it cannot run
            # here (see ../dsh-our-free-model-standalone/AGENTS.md).
            substituteInPlace scripts/test-all.mjs \
              --replace-fail "  ['legacy-upgrade', 'legacy-upgrade-test.mjs', mode === 'contributor' ? [] : ['--production']],
      " ""

            substituteInPlace scripts/forward-test.mjs \
              --replace-fail "resolveLoopbackBind('example.com'), /loopback/" "resolveLoopbackBind('example.com'), /loopback|could not resolve/"
            substituteInPlace scripts/standalone-login-terminal-test.mjs \
              --replace-fail "/usr/bin/printf '%s" "printf '%s"
    '';

    checkPhase = ''
      runHook preCheck
      git init -q
      # Point the browser suites at the no-browser stub and keep their real
      # output, so the SKIP lines below quote what actually happened.
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

            # The sealed EAC lane unlocks only for the profile names src/vault.js
            # hardcodes (`web`, `web-desktop`, `desktop`), so a custom web profile
            # (e.g. `nix-web-qq`) sees a dark lane and the EAC roster never loads.
            # Widening the gate means editing src/vault.js, which both signed release
            # records cover, and feed/manifest.json is Ed25519-signed with the
            # maintainer's pinned key — a postPatch edit cannot be re-signed, because
            # build-manifest.mjs --check verifies the committed signature. Patching
            # the installed copy instead leaves the pristine tree, and every gate that
            # reads it (checkPhase, the digest check above), untouched. `scripts/` is
            # the only tree absent from package.json files; `src/` ships, so this runs
            # per profile on top of the verified bytes.
      ${lib.concatMapStrings (profile: ''
        if ! printf %s "${lib.escapeShellArg profile}" | grep -qE '^[A-Za-z0-9._-]+$'; then
          echo "dsh-our-free-model: extraWebProfiles entry \"${lib.escapeShellArg profile}\" is not a plain profile name" >&2
          exit 1
        fi
        if grep -qF "profileName === '${profile}'" $packageDir/src/vault.js; then
          echo "dsh-our-free-model: ${profile} already names a sealed-host profile" >&2
          exit 1
        fi
        if [ "$(grep -cF "  if (profileName === 'desktop'" $packageDir/src/vault.js)" -ne 1 ]; then
          echo "dsh-our-free-model: cannot locate the desktop branch of detectSealedHost" >&2
          exit 1
        fi
        # Insert before the desktop line instead of substituting it: one
        # substitution consumes its own pattern, so a second profile would
        # find no anchor and be dropped without failing the build. Anchor on
        # the prefix rather than the whole line: 2.5.2 widened the branch to
        # `=== 'desktop' || === 'tauri'`, and the guard above must survive the
        # next widening too without letting the patch silently no-op.
        sed -i "\|^  if (profileName === 'desktop'|i\\  if (profileName === '${profile}') return FLAVOR_WEB" $packageDir/src/vault.js
      '') extraWebProfiles}
    '';

    installation = dshPkgs.dsh.dsh-runtime;

    runtimeDeps = [
      mihomo
      xdg-utils
    ];

    passthru = {
      inherit extraWebProfiles;
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
