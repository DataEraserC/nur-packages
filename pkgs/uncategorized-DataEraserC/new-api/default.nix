# https://github.com/JulienMalka/snowfield/blob/4fe72361dbdd0113d12fe44a8f492ee1eb6cb9cc/packages/new-api/default.nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  buildGoModule,
  bun,
  cacert,
  nodejs,
}:

let
  version = "1.0.0-rc.44";

  src = fetchFromGitHub {
    owner = "QuantumNous";
    repo = "new-api";
    tag = "v${version}";
    hash = "sha256:sha256-fbfoKBKp4y3kiHPHp//JcICxUm0BOav7ZAK/V3TU1R4=";
  };

  # nixpkgs has no fetcher for bun lockfiles, so node_modules is a
  # fixed-output derivation: `bun install --frozen-lockfile` with the
  # lifecycle scripts disabled, hashed as a whole.
  webDeps = stdenv.mkDerivation {
    pname = "new-api-web-deps";
    inherit version;
    src = "${src}/web";
    nativeBuildInputs = [
      bun
      cacert
    ];
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
      bun install --frozen-lockfile --ignore-scripts --no-progress --no-summary
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      cp -R node_modules $out
      runHook postInstall
    '';
    dontFixup = true;
    outputHashMode = "recursive";
    outputHash = "sha256-tuaI4RBa4NUlTOORUogAKzHwuYQ3xNaqtk3k0LmYQP8=";
  };

  web = stdenv.mkDerivation {
    pname = "new-api-web";
    inherit version;
    src = "${src}/web";
    nativeBuildInputs = [
      bun
      nodejs
    ];
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      cp -R ${webDeps} node_modules
      chmod -R u+w node_modules
      # .bin entries are symlinks; patch the scripts they point to.
      patchShebangs $(readlink -f node_modules/.bin/*)
      DISABLE_ESLINT_PLUGIN=true VITE_REACT_APP_VERSION=v${version} bun run build
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      cp -R dist $out
      runHook postInstall
    '';
  };
in
buildGoModule {
  pname = "new-api";
  inherit version src;

  vendorHash = "sha256-QiF7XBGmUqFOjndRSZrd51fFcdvumZdABFcIUZ7wMxU=";

  # The vendor derivation must not depend on the frontend build.
  overrideModAttrs = _: {
    preBuild = "";
  };

  # The Go binary embeds web/dist (see main.go).
  preBuild = ''
    rm -rf web/dist
    cp -R ${web} web/dist
  '';

  subPackages = [ "." ];
  ldflags = [
    "-s"
    "-w"
    "-X github.com/QuantumNous/new-api/common.Version=v${version}"
  ];

  # The upstream test suite needs network and databases.
  doCheck = false;

  passthru.updateScript = [ (toString ./update.sh) ];

  meta = {
    description = "OpenAI-compatible LLM gateway with users, API tokens, quotas and usage logs";
    homepage = "https://github.com/QuantumNous/new-api";
    license = lib.licenses.agpl3Only;
    mainProgram = "new-api";
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.linux;
  };
}
