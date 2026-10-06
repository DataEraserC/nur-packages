{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs_24,
  versionCheckHook,
  nix-update-script,
  stdenv,
  zlib,
  libsecret,
}:

buildNpmPackage (finalAttrs: {
  pname = "omniroute";
  version = "3.8.51";

  src = fetchFromGitHub {
    owner = "diegosouzapw";
    repo = "OmniRoute";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ZYRjwynEw3cziFp8tM483QN96mDH0ZuHCFuhcJDwelA=";
  };

  nodejs = nodejs_24;

  npmDepsHash = "sha256-GYrlfaaeE2GnuatOr3C7N2To9GjCEelM7Kw2nT1/5F8=";

  npmRebuildFlags = [ "--ignore-scripts" ];
  npmFlags = [
    "--no-audit"
    "--no-fund"
  ];

  env = {
    NEXT_TELEMETRY_DISABLED = "1";
    OMNIROUTE_USE_TURBOPACK = "0";
    CIRCLE_NODE_TOTAL = "2";
    NPM_CONFIG_LEGACY_PEER_DEPS = "true";
    OMNIROUTE_BASE_PATH = "";
    DASHBOARD_ALLOW_EMBED = "";
    LD_LIBRARY_PATH = lib.makeLibraryPath [
      stdenv.cc.cc.lib
      zlib
      libsecret
    ];
  };

  nativeBuildInputs = [ makeWrapper ];

  postConfigure = ''
    (cd node_modules/better-sqlite3 && ${nodejs_24}/bin/node "$npm_config_node_gyp" rebuild --release --force_build=1 --nodedir="$npm_config_nodedir")
    test -e node_modules/better-sqlite3/build/Release/better_sqlite3.node
    ${nodejs_24}/bin/node -e "require('better-sqlite3')(':memory:').close()"
    ${nodejs_24}/bin/node -e "const wreq = require('wreq-js'); if (typeof wreq.createTransport !== 'function') throw new Error('wreq-js createTransport unavailable');"
  '';

  doCheck = false;

  postBuild = ''
    (cd .build/next/standalone && ${nodejs_24}/bin/node -e "for (const m of ['@atjsh/llmlingua-2', '@huggingface/transformers', 'js-tiktoken', 'onnxruntime-node']) require.resolve(m)")
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/omniroute
    cp -a .build/next/standalone/. $out/lib/omniroute/
    mkdir -p $out/lib/omniroute/node_modules
    rm -rf $out/lib/omniroute/node_modules/better-sqlite3
    cp -a node_modules/better-sqlite3 $out/lib/omniroute/node_modules/
    test -e $out/lib/omniroute/node_modules/better-sqlite3/build/Release/better_sqlite3.node
    test -d $out/lib/omniroute/migrations
    test -e $out/lib/omniroute/dev/run-standalone.mjs

    find $out -type l -lname '/build/*' | while read -r link; do
      target=$(readlink "$link")
      case "$target" in
        /build/source/*)
          replacement="$out/lib/omniroute/''${target#/build/source/}"
          if [ -e "$replacement" ]; then
            ln -sfn "$replacement" "$link"
            continue
          fi
          ;;
      esac
      rm -f "$link"
    done
    find $out -xtype l -delete

    makeWrapper ${lib.getExe' nodejs_24 "node"} $out/bin/omniroute \
      --run "if [ \"\$1\" = \"--version\" ]; then exec ${nodejs_24}/bin/node -p \"require('$out/lib/omniroute/package.json').version\"; fi" \
      --chdir $out/lib/omniroute \
      --prefix PATH : ${lib.makeBinPath [ nodejs_24 ]} \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          stdenv.cc.cc.lib
          zlib
          libsecret
        ]
      } \
      --set-default OMNIROUTE_MIGRATIONS_DIR $out/lib/omniroute/migrations \
      --set-default OMNIROUTE_MEMORY_MB 1024 \
      --set-default NODE_OPTIONS --max-old-space-size=1024 \
      --set-default OMNIROUTE_BASE_PATH "" \
      --set-default DASHBOARD_ALLOW_EMBED "" \
      --add-flags $out/lib/omniroute/dev/run-standalone.mjs

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--version";

  passthru.updateScript = nix-update-script { };
  passthru.aiProvenance = [
    {
      agent = "dsh";
      model = "mimo-v2.6-flash-free";
      involvement = "authored";
    }
  ];

  meta = {
    description = "Unified AI router with 358 providers, RTK+Caveman compression, auto fallback, MCP/A2A, desktop, PWA, and OpenAI-compatible APIs";
    homepage = "https://github.com/diegosouzapw/OmniRoute";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    mainProgram = "omniroute";
    platforms = lib.platforms.linux;
  };
})
