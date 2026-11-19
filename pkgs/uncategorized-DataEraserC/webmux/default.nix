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
    rev = "d1d79be1d24ff41a7a134d42df7961cf19bc08bd";
    hash = "sha256-GcuuRI1M0dFiZVvRa+ltxYqpvLICELY5k5H/HoOoyOM=";
  },
}:

let
  version = "0.18.0-unstable-2026-11-19";
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
    hash = "sha256-jeufMwHqygtsf2FdXQIN/okE2lyVjS+EjYy+2fxXGv4=";
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
      # Upstream aliases the `vite` catalog entry to @voidzero-dev/vite-plus-core
      # (no `vite` binary); the CLI is `vp`, which is what `vp build` runs.
      pnpm exec vp build
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
  vendorHash = "sha256-MgJHAW4nYErnvG8alg1PnDbvZClTPQKLd/To3NGjkUw=";

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
