{
  lib,
  buildNpmPackage,
  fetchurl,
  nix-update-script,
  nodejs_24,
  versionCheckHook,
}:
buildNpmPackage (finalAttrs: {
  pname = "9router";
  version = "0.5.104";

  src = fetchurl {
    url = "https://registry.npmjs.org/9router/-/9router-${finalAttrs.version}.tgz";
    hash = "sha256-96CLtldJk9zxVySZhYutnojJNUJiWNh1Hs47/XDzKKc=";
  };

  __structuredAttrs = true;
  strictDeps = true;

  nodejs = nodejs_24;

  npmDepsHash = "sha256-R3RFTB7Trm75fbVsCtFo+wb/jRTrIG4ZC5kKDQdQHKo=";

  postPatch = ''
    ${lib.getExe' nodejs_24 "node"} --eval '
      const fs = require("fs");
      const pkg = require("./package.json");
      delete pkg.devDependencies;
      fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2));
    '

    cp ${./package-lock.json} package-lock.json
    chmod u+w package-lock.json

    rm -rf app/cli/.build-home
  '';

  dontNpmBuild = true;

  npmFlags = [ "--ignore-scripts" ];

  makeWrapperArgs = [
    "--set"
    "NODE_ENV"
    "production"
  ];

  postInstall = ''
    test -f $out/lib/node_modules/9router/app/custom-server.js
    test -f $out/lib/node_modules/9router/app/server.js
    test -f $out/lib/node_modules/9router/app/.next-cli-build/BUILD_ID
    test -f $out/lib/node_modules/9router/app/node_modules/next/package.json
    test -f $out/lib/node_modules/9router/node_modules/node-machine-id/package.json
    test ! -e $out/lib/node_modules/9router/app/cli/.build-home
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--version";

  passthru.updateScript = nix-update-script { };
  passthru.aiProvenance = [
    {
      agent = "dsh";
      model = "deepseek-v4.1-flash";
      involvement = "authored";
    }
  ];

  meta = {
    description = "Local AI gateway that routes coding agent requests across multiple providers with automatic fallback";
    homepage = "https://github.com/decolua/9router";
    changelog = "https://github.com/decolua/9router/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "9router";
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.unix;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
  };
})
