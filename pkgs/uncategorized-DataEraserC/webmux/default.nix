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
  unstableGitUpdater,
  versionCheckHook,
  writeShellApplication,
}:

let
  version = "0.14.4-unstable-2026-11-11";

  src = fetchFromGitHub {
    owner = "mzdluo123";
    repo = "webmux";
    rev = "cf23a4036a525b569bc562c913c3ae05c5973fcc";
    hash = "sha256-kFmtz744vHA9wqw+RfYE54u5NwBnU5F7sAm42UrSXzE=";
  };

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
    hash = "sha256-NP63QLqCd9tYgHBd7v+G90EupZF9MKoo3IKW48svUrs=";
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
  vendorHash = "sha256-Je+YqoTY0A5VCNtBBMpGjcmHLa2otbuKydnYGDEVCl0=";

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
