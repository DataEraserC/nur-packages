{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  git,
  pnpm_12,
  pnpmConfigHook,
  nodejs_26,
  buildGo127Module,
  nix-update-script,
  unstableGitUpdater,
  versionCheckHook,
  writeShellApplication,
  webmuxSource ? fetchFromGitHub {
    owner = "mzdluo123";
    repo = "webmux";
    rev = "0bdd93c2f2c013e39252e0ca26fb8b623db4212d";
    hash = "sha256-New0DtlYXOU7owGZ822HefOzB78E7TPSy3zvuKFI+Fk=";
  },
}:

let
  version = "0.16.0-unstable-2026-11-15";
  src = webmuxSource;

  sourceUpdater = unstableGitUpdater {
    url = "https://github.com/mzdluo123/webmux.git";
    tagFormat = "v*";
    tagPrefix = "v";
  };

  dependencyUpdater = nix-update-script {
    extraArgs = [
      "--version"
      "skip"
      "--no-src"
    ];
  };

  updater = writeShellApplication {
    name = "webmux-update";
    derivationArgs = {
      __structuredAttrs = true;
      strictDeps = true;
    };
    text = ''
      ${lib.escapeShellArgs sourceUpdater}
      ${lib.escapeShellArgs dependencyUpdater}
    '';
  };

  webPnpmDeps = fetchPnpmDeps {
    pname = "webmux-web";
    inherit version src;
    sourceRoot = "source/web";
    pnpm = pnpm_12;
    fetcherVersion = 4;
    hash = "sha256-5OyJovg1SiQN1yRygM5TH11Q5reWiGEj3xxmvp7HNN4=";
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
buildGo127Module (finalAttrs: {
  pname = "webmux";
  inherit version src;
  __structuredAttrs = true;
  strictDeps = true;
  vendorHash = "sha256-8jgAcb9znAtAlDfwuBD5+qTimc3mwoCRZ38i6pHr/d4=";

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

  # CLI tests shell out to `git` (worktree / workspace tests). The build
  # sandbox has no git on PATH, so `go test ./...` fails without it.
  nativeCheckInputs = [ git ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--version";

  passthru = {
    updateScript = lib.getExe updater;
    # nix-update reads pkg.pnpmDeps.outputHash; without this the frontend's
    # hash in the let-bound webPnpmDeps goes stale on version bumps
    pnpmDeps = webPnpmDeps;
    aiProvenance = [
      {
        agent = "dsh";
        model = "1AgentRouter/gpt-5.6-sol";
        involvement = "assisted";
      }
      {
        agent = "dsh";
        model = "2AgentRouter/gpt-5.6-sol";
        involvement = "assisted";
      }
    ];
  };

  meta = {
    changelog = "https://github.com/mzdluo123/webmux/releases";
    description = "Browser-based persistent terminal server that keeps sessions alive across disconnects";
    homepage = "https://github.com/mzdluo123/webmux";
    license = lib.licenses.mit;
    mainProgram = "webmux";
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.unix;
  };
})
