# https://github.com/JulienMalka/snowfield/blob/4fe72361dbdd0113d12fe44a8f492ee1eb6cb9cc/packages/new-api/default.nix
{
  lib,
  stdenv,
  fetchFromGitHub,
  buildGo127Module,
  bun,
  cacert,
  jq,
  nodejs,
}:

let
  version = "1.0.0-rc.51";

  src = fetchFromGitHub {
    owner = "QuantumNous";
    repo = "new-api";
    tag = "v${version}";
    hash = "sha256-+XqwHVCHs89gxWn0lNMkAnI3IF34RSlaq4XX3g9eSFg=";
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
      jq
    ];
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
      bun install --frozen-lockfile --ignore-scripts --no-progress --no-summary
      # bun before 1.4.4 installs optional packages whose `libc` field does not
      # match the host (e.g. @rspack/binding-linux-x64-musl on glibc), while
      # 1.4.4 skips them. Pruning the mismatches here keeps the fixed output
      # identical across bun versions instead of breaking on every bun bump.
      hostLibc=${if stdenv.hostPlatform.isMusl then "musl" else "glibc"}
      find node_modules -mindepth 2 -maxdepth 3 -name package.json -print0 |
        xargs -0 -r jq -r --arg libc "$hostLibc" \
          'select(.libc and (.libc | index($libc) | not)) | input_filename' |
        while IFS= read -r manifest; do
          printf 'pruning libc-mismatched package: %s\n' "$(dirname "$manifest")"
          rm -rf "$(dirname "$manifest")"
        done
      find node_modules -xtype l -delete
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      cp -R node_modules $out
      runHook postInstall
    '';
    dontFixup = true;
    outputHashMode = "recursive";
    outputHash = "sha256-5BQYf67ivYXYeHSgJEqQSZIeZ5gWjq4H0UqLByx9pAQ=";
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
buildGo127Module {
  pname = "new-api";
  inherit version src;

  vendorHash = "sha256-qmc7w/dLlBUzt0Am3KHmIXmuglGCymWFzdLRdHf8I3w=";

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

  passthru = {
    # Exposed so update.sh can build the frontend dependencies directly to
    # confirm a freshly probed outputHash before writing it into the package.
    inherit webDeps;
    aiProvenance = [
      {
        agent = "dsh";
        model = "deepseek-flash";
        involvement = "assisted";
      }
    ];
    updateScript = [ (toString ./update.sh) ];
  };

  meta = {
    description = "OpenAI-compatible LLM gateway with users, API tokens, quotas and usage logs";
    homepage = "https://github.com/QuantumNous/new-api";
    license = lib.licenses.agpl3Only;
    mainProgram = "new-api";
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.linux;
  };
}
