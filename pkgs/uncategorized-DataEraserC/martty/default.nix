{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
  autoPatchelfHook,
  nodejs_24,
  versionCheckHook,
}:
buildNpmPackage (finalAttrs: {
  pname = "martty";
  version = "0.3.3";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    url = "https://registry.npmjs.org/martty/-/martty-${finalAttrs.version}.tgz";
    hash = "sha256-C7hUNIUh8q03Q6FFGncLltQhZw3vfIhWy0lnUJCEyuQ=";
  };

  sourceRoot = "package";
  nodejs = nodejs_24;

  npmDepsHash = "sha256-Zwi8/k7kNCR9J5yTOIT4dxfBLV8Bctt56mdJMkrqvUM=";
  npmFlags = [ "--omit=dev" ];
  dontNpmBuild = true;
  dontNpmPrune = true;

  makeWrapperArgs = [
    "--set"
    "NODE_ENV"
    "production"
  ];

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  postInstall = ''
    local modules=$out/lib/node_modules/martty/node_modules
    rm -rf "$modules/@deepseek-ai/dsh-win32-process"
    find "$modules" -type d \( -name musl -o -name 'musl_*' \) -prune -exec rm -rf {} +
    if [ -d "$modules/node-pty/prebuilds" ]; then
      find "$modules/node-pty/prebuilds" -mindepth 1 -maxdepth 1 \
        ! -name "${
          if stdenv.hostPlatform.isx86_64 then "linux-x64" else "linux-arm64"
        }" -exec rm -rf {} +
    fi
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--version";

  passthru.updateScript = [ (toString ./update.sh) ];

  meta = {
    description = "Terminal-native ACP client UI that runs any ACP agent";
    homepage = "https://martty.sh";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    mainProgram = "martty-cli";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
