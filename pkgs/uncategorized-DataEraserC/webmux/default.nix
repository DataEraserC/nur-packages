{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_12,
  pnpmConfigHook,
  nodejs_26,
  buildGoModule,
  nix-update-script,
  versionCheckHook,
}:

let
  version = "0.12.1";

  src = fetchFromGitHub {
    owner = "mzdluo123";
    repo = "webmux";
    tag = "v${version}";
    hash = "sha256-wdFjwm3M4/61TtJvD4DQMc0wLLPAsXNrBBP1A+jMHuY=";
  };

  webPnpmDeps = fetchPnpmDeps {
    pname = "webmux-web";
    inherit version src;
    sourceRoot = "source/web";
    pnpm = pnpm_12;
    fetcherVersion = 4;
    hash = "sha256-/KJh4BmQ1zj63HcK7ukuSTxiC1ZnVP2tdTuu4IYnq74=";
  };

  frontendDist = stdenv.mkDerivation {
    pname = "webmux-web-dist";
    inherit version src;
    sourceRoot = "source/web";
    __structuredAttrs = true;
    strictDeps = true;
    pnpmDeps = webPnpmDeps;
    nativeBuildInputs = [
      nodejs_26
      pnpm_12
      pnpmConfigHook
    ];
    buildPhase = ''
      runHook preBuild
      pnpm exec vite build
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp dist/embed.zip $out/
      runHook postInstall
    '';
  };
in
buildGoModule (finalAttrs: {
  pname = "webmux";
  inherit version src;
  __structuredAttrs = true;
  strictDeps = true;
  vendorHash = "sha256-t7j9hOvZhYzNwBhLVBtn1vbm0WVptKERzLNAhs5b+Ms=";

  subPackages = [ "cmd/webmux" ];

  patches = [ ./codebuddy-agent.patch ];

  preBuild = ''
    mkdir -p web/dist
    cp ${frontendDist}/embed.zip web/dist/embed.zip
  '';

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--version";

  passthru = {
    updateScript = nix-update-script { };
    # nix-update reads pkg.pnpmDeps.outputHash; without this the frontend's
    # hash in the let-bound webPnpmDeps goes stale on version bumps
    pnpmDeps = webPnpmDeps;
  };

  meta = {
    changelog = "https://github.com/mzdluo123/webmux/releases/tag/v${finalAttrs.version}";
    description = "Browser-based persistent terminal server that keeps sessions alive across disconnects";
    homepage = "https://github.com/mzdluo123/webmux";
    license = lib.licenses.mit;
    mainProgram = "webmux";
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.unix;
  };
})
