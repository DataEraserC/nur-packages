{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchNpmDeps,
  fetchPnpmDeps,
  pnpm_12,
  pnpmConfigHook,
  npmHooks,
  nodejs_24,
  git,
  prefetch-npm-deps,
  lobsteraiSrc,
}:

let
  version = "2026.8.1";

  openclawSrc = fetchFromGitHub {
    owner = "openclaw";
    repo = "openclaw";
    tag = "v${version}";
    hash = "sha256-2h446gX7TJpOlj4Z7pMsmqyalWK2IgPePhspyqtEhkk=";
  };

  openclawPnpmDeps = fetchPnpmDeps {
    pname = "lobsterai-openclaw-runtime";
    inherit version;
    src = openclawSrc;
    pnpm = pnpm_12;
    fetcherVersion = 4;
    hash = "sha256-0uQN8a+6WxQ7NV5EMaX9RtMj666irv68JO0IzVHB3Cw=";
  };

  appDeps = fetchNpmDeps {
    name = "lobsterai-openclaw-runtime-app-${version}-npm-deps";
    src = lobsteraiSrc;
    hash = "sha256-7QeQky1pqhlK+rXSrOATKHrIzd9KNIaw3KyX5iUk2DE=";
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';
  };

  prodDeps = fetchNpmDeps {
    name = "lobsterai-openclaw-runtime-prod-${version}-npm-deps";
    src = ./openclaw-prod;
    hash = "sha256-77i5IYlvA0NFl/t8xvWaUqyrDvOcwHEwWKNR/Z/s7a4=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "lobsterai-openclaw-runtime";
  inherit version;

  __structuredAttrs = true;
  strictDeps = true;

  env.OPENCLAW_BUILD_ALL_NO_PNPM = "1";

  src = openclawSrc;
  pnpmDeps = openclawPnpmDeps;
  npmDeps = appDeps;
  npmRoot = "../lobsterai";

  # The LobsterAI tree is unpacked here only to run the runtime build scripts;
  # `npm rebuild` would compile selection-hook against X11 headers for a
  # prebuild it already ships, and nothing from this node_modules is installed.
  npmRebuildFlags = [ "--ignore-scripts" ];

  postUnpack = ''
    cp -r ${lobsteraiSrc} "$NIX_BUILD_TOP/lobsterai"
    chmod -R u+w "$NIX_BUILD_TOP/lobsterai"
    cp ${./package-lock.json} "$NIX_BUILD_TOP/lobsterai/package-lock.json"
    chmod u+w "$NIX_BUILD_TOP/lobsterai/package-lock.json"
  '';

  nativeBuildInputs = [
    nodejs_24
    pnpm_12
    pnpmConfigHook
    npmHooks.npmConfigHook
    git
    prefetch-npm-deps
  ];

  postPatch = ''
    patch -p1 --batch --forward --no-backup-if-mismatch \
      < ${./openclaw-nix-store-plugin-hardlink.patch}

    patch -d "$NIX_BUILD_TOP/lobsterai" -p1 --batch --forward --no-backup-if-mismatch \
      < ${./openclaw-runtime-offline.patch}

    substituteInPlace "$NIX_BUILD_TOP/lobsterai/scripts/build-openclaw-runtime.sh" \
      --replace-fail 'pnpm install --frozen-lockfile --fetch-timeout' \
                     'pnpm install --frozen-lockfile --ignore-scripts --fetch-timeout'
  '';

  buildPhase = ''
    runHook preBuild

    export OPENCLAW_TSDOWN_MAX_OLD_SPACE_MB=4096

    git init -q .
    git add -A
    git -c user.email=nix@localhost -c user.name=nix commit -qm init

    export ELECTRON_ROOT="$NIX_BUILD_TOP/lobsterai"
    export OPENCLAW_SRC="$PWD"
    export CFMIND_PACKAGE_JSON="${./cfmind-package.json}"
    export CFMIND_PACKAGE_LOCK="${./cfmind-package-lock.json}"
    export npm_config_offline="true"
    export CACHE_MAP_PATH="$TMPDIR/prod-cache-map"
    npmDeps="${prodDeps}" prefetch-npm-deps --map-cache
    cp -r "${prodDeps}" "$TMPDIR/prod-cache"
    chmod -R u+w "$TMPDIR/prod-cache"
    export npm_config_cache="$TMPDIR/prod-cache"

    node "$ELECTRON_ROOT/scripts/apply-openclaw-patches.cjs" "$OPENCLAW_SRC"

    bash "$ELECTRON_ROOT/scripts/build-openclaw-runtime.sh" linux-x64

    pushd "$ELECTRON_ROOT" >/dev/null
    node scripts/sync-openclaw-runtime-current.cjs linux-x64
    node scripts/bundle-openclaw-startup-migration.cjs
    node scripts/bundle-openclaw-gateway.cjs
    mkdir -p vendor/openclaw-runtime/current/third-party-extensions
    node scripts/sync-local-openclaw-extensions.cjs
    node scripts/precompile-openclaw-extensions.cjs
    node scripts/prune-openclaw-runtime.cjs
    popd >/dev/null

    patchShebangs "$ELECTRON_ROOT/vendor/openclaw-runtime/linux-x64/node_modules/.bin"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -r "$NIX_BUILD_TOP/lobsterai/vendor/openclaw-runtime/linux-x64/." "$out/"

    runHook postInstall
  '';

  meta = {
    description = "OpenClaw agent runtime embedded into LobsterAI, built from patched upstream sources";
    homepage = "https://github.com/openclaw/openclaw";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.linux;
  };
})
