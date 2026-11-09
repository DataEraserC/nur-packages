{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  git,
  pnpm_12,
  pnpmConfigHook,
  nodejs_26,
  buildGoModule,
  nix-update-script,
  versionCheckHook,
}:

let
  version = "0.14.1";

  src = fetchFromGitHub {
    owner = "mzdluo123";
    repo = "webmux";
    tag = "v${version}";
    hash = "sha256-FMFTbVd2wY00iPEuQsrnMXbVFsJ+UxDIggHVyJK9MGA=";
  };

  webPnpmDeps = fetchPnpmDeps {
    pname = "webmux-web";
    inherit version src;
    sourceRoot = "source/web";
    pnpm = pnpm_12;
    fetcherVersion = 4;
    hash = "sha256-mXzBS6RIQ61HMGuWDeKDeKeR3ZEyo6kRrzfXL42R94Y=";
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
  vendorHash = "sha256-86gMpaRVlJGjeEzLXoVYawIat2QM4EGdxHEtBI9DbZo=";

  subPackages = [ "cmd/webmux" ];

  preBuild = ''
    mkdir -p web/dist
    cp ${frontendDist}/embed.zip web/dist/embed.zip
  '';

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  # 0.14.1's CLI tests shell out to `git` (worktree / workspace tests). The
  # build sandbox has no git on PATH, so `go test ./...` fails without it.
  nativeCheckInputs = [ git ];

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
