{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchNpmDeps,
  npmHooks,
  nodejs_24,
  electron_43,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  callPackage,
}:

let
  version = "2026.10.13";

  src = fetchFromGitHub {
    owner = "netease-youdao";
    repo = "LobsterAI";
    tag = version;
    hash = "sha256-gDfILyA3ksuaBHR43ygCnvNDJAOF6PyU1iWK+1BnBBk=";
  };

  openclawRuntime = callPackage ./openclaw-runtime.nix { lobsteraiSrc = src; };

  mkSkill =
    {
      pname,
      description,
      skillDir,
      lockfile,
      hash,
      buildScript ? "",
    }:
    let
      skillDeps = fetchNpmDeps {
        name = "${pname}-${version}-npm-deps";
        inherit src hash;
        postPatch = ''
          cp ${lockfile} package-lock.json
        '';
      };
    in
    stdenv.mkDerivation {
      inherit pname version src;
      __structuredAttrs = true;
      strictDeps = true;
      npmDeps = skillDeps;
      npmRoot = skillDir;

      nativeBuildInputs = [
        nodejs_24
        npmHooks.npmConfigHook
      ];

      postPatch = ''
        cp ${lockfile} package-lock.json
        cp ${lockfile} ${skillDir}/package-lock.json
      '';

      buildPhase = ''
        runHook preBuild
        ${buildScript}
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -a ${skillDir}/. "$out/"
        runHook postInstall
      '';

      meta = {
        inherit description;
        homepage = "https://github.com/netease-youdao/LobsterAI";
        license = lib.licenses.mit;
        maintainers = import ../maintainers.nix;
        platforms = lib.platforms.linux;
      };
    };

  skillWebSearch = mkSkill {
    pname = "lobsterai-skill-web-search";
    description = "Bundled dependencies for the LobsterAI web-search skill";
    skillDir = "SKILLs/web-search";
    lockfile = ./skills/web-search/package-lock.json;
    hash = "sha256-plOzbWV9BlgosdtYzHYFYA2cwGu1b0vJnMZLcH2tK+w=";
    buildScript = ''
      (
        cd SKILLs/web-search
        ./node_modules/.bin/tsc -p tsconfig.json
      )
      node -e "const fs=require('fs');['.connection','.server.log','.server.pid'].forEach(f=>{try{fs.unlinkSync('SKILLs/web-search/'+f)}catch(e){}});"
    '';
  };

  skillEmail = mkSkill {
    pname = "lobsterai-skill-email";
    description = "Bundled dependencies for the LobsterAI IMAP and SMTP email skill";
    skillDir = "SKILLs/imap-smtp-email";
    lockfile = ./skills/imap-smtp-email/package-lock.json;
    hash = "sha256-vFmpZFvW0CnnUsBJJfttvLgSUvUx/BcHThEfsFzfK8M=";
  };

  skillPptx = mkSkill {
    pname = "lobsterai-skill-pptx";
    description = "Bundled dependencies for the LobsterAI presentation skill";
    skillDir = "SKILLs/pptx";
    lockfile = ./skills/pptx/package-lock.json;
    hash = "sha256-+LFfVwv+FvZsBq8sQtlEF/8OG2EJtQF2RsPSuQ3zfkE=";
  };

  appDeps = fetchNpmDeps {
    name = "lobsterai-${version}-npm-deps";
    inherit src;
    hash = "sha256-Kc2CG6k5gglTRRqSfD2wXxcdyNe65fOOM1feuaK6jNg=";
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "lobsterai";
  inherit version src;

  __structuredAttrs = true;
  strictDeps = true;

  npmDeps = appDeps;
  env.makeCacheWritable = true;

  dontStrip = true;
  dontPatchELF = true;

  nativeBuildInputs = [
    nodejs_24
    npmHooks.npmConfigHook
    makeWrapper
    copyDesktopItems
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "lobsterai";
      desktopName = "LobsterAI";
      genericName = "AI Assistant";
      comment = "AI-assisted coding and productivity tool";
      exec = "lobsterai %U";
      icon = "lobsterai";
      startupWMClass = "LobsterAI";
      mimeTypes = [ "x-scheme-handler/lobsterai" ];
      categories = [ "Utility" ];
      keywords = [
        "AI"
        "assistant"
        "coding"
      ];
    })
  ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  preBuild = ''
    ./node_modules/.bin/patch-package --error-on-fail
  '';

  buildPhase = ''
    runHook preBuild

    cp -r ${skillWebSearch}/. SKILLs/web-search/
    cp -r ${skillPptx}/. SKILLs/pptx/
    cp -r ${skillEmail}/. SKILLs/imap-smtp-email/

    npm run build
    npm run compile:electron
    npm run build:skill:tech-news

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    app="$out/opt/lobsterai"
    mkdir -p "$app"
    cp -r ${electron_43.dist}/. "$app/"
    mv "$app/electron" "$app/LobsterAI"
    chmod -R u+w "$app"

    mkdir -p "$app/resources/app/resources"
    cp package.json "$app/resources/app/package.json"
    cp -r dist "$app/resources/app/dist"
    cp -r dist-electron "$app/resources/app/dist-electron"
    cp resources/SYSTEM_PROMPT.md "$app/resources/app/resources/SYSTEM_PROMPT.md"

    cp package-lock.json "$app/resources/app/package-lock.json"
    pushd "$app/resources/app" >/dev/null
    npm ci --omit=dev --ignore-scripts --no-audit --no-fund
    popd >/dev/null
    rm -f "$app/resources/app/package-lock.json"
    patchShebangs "$app/resources/app/node_modules/.bin"

    mkdir -p "$app/resources/licenses/word" "$app/resources/licenses/sheet"
    cp -r resources/word-licenses/. "$app/resources/licenses/word/"
    cp -r resources/sheet-licenses/. "$app/resources/licenses/sheet/"

    cp -r .keyfrom-build "$app/resources/keyfrom"
    cp -r resources/tray "$app/resources/tray"
    mkdir -p "$app/resources/app-icon"
    install -Dm644 build/icons/png/512x512.png "$app/resources/app-icon/512x512.png"

    mkdir -p "$app/resources/cfmind"
    cp -r ${openclawRuntime}/. "$app/resources/cfmind/"
    cp -r SKILLs "$app/resources/SKILLs"

    install -Dm644 build/icons/png/512x512.png "$out/share/icons/hicolor/512x512/apps/lobsterai.png"

    mkdir -p "$out/bin"
    makeWrapper "$app/LobsterAI" "$out/bin/lobsterai" \
      --add-flags "--no-sandbox" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}"

    runHook postInstall
  '';

  passthru = {
    npmDeps = appDeps;
    aiProvenance = [
      {
        agent = "dsh";
        model = "mimo-v2.6-flash-free";
        involvement = "authored";
      }
    ];
    inherit openclawRuntime skillWebSearch skillEmail skillPptx;
  };

  meta = {
    description = "AI assistant for coding and productivity with an embedded OpenClaw agent runtime";
    homepage = "https://github.com/netease-youdao/LobsterAI";
    license = lib.licenses.mit;
    mainProgram = "lobsterai";
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.linux;
  };
})
