{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  nix-update-script,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-headless-display requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-headless-display)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-headless-display";
    version = "1.4.1";

    src = fetchFromGitHub {
      owner = "jingyingruodi";
      repo = "dsh-headless-display";
      tag = "v${finalAttrs.version}";
      hash = "sha256-wFnLqRE70FX8I3eNuGD1ZrlPmXHfbcaBeZ9fR7IUC9s=";
    };

    # doctor() emitted `undefined` for fields that legitimately have no value on
    # this host (per-dependency `package` under an unrecognised distro,
    # `backends.sway.gpu` when the backend is not sway). DSH validates tool
    # results as lossless JSON and rejects the whole call on the first
    # `undefined`, even though the HTTP route looks fine because
    # JSON.stringify drops those keys. `null` says the same thing and survives.
    patches = [ ./patches/0001-doctor-return-null-instead-of-undefined.patch ];

    # Upstream is a dependency-free, prebuilt-cordis bundle (no dependencies,
    # peerDependencies or lockfile at all), so there is nothing for npm to
    # install and no npmDeps FOD to fetch. Overriding npmConfigHook with an
    # empty directory skips the hook entirely (passing null would restore the
    # default hook, which insists on npmDeps plus a package-lock.json).
    npmDeps = null;
    npmConfigHook = pkgs.emptyDirectory;
    dontNpmBuild = true;

    postPatch = ''
      # nixpkgs' gtk-vnc ships only gvnccapture, not the GTK viewer, so the
      # default viewer (gvncviewer) can never be resolved here. Fall back to
      # TigerVNC's vncviewer, which the plugin already detects by basename and
      # drives with its `localhost::<port>` + -Shared syntax.
      substituteInPlace plugin.js \
        --replace-fail "viewer: config.viewerPath || 'gvncviewer'," \
          "viewer: config.viewerPath || 'vncviewer',"
    '';

    installPhase = ''
      runHook preInstall

      packageDir=$out/lib/node_modules/dsh-headless-display
      mkdir -p $packageDir
      cp -r plugin.js client.js cordis.patch.yml icon.svg README.md LICENSE package.json $packageDir/
      cp -r locale scripts docs $packageDir/

      runHook postInstall
    '';

    postInstall = ''
      packageDir=$out/lib/node_modules/dsh-headless-display
      test -f $packageDir/plugin.js
      test -f $packageDir/client.js
      test -f $packageDir/cordis.patch.yml
      test -f $packageDir/locale/zh.json
      test -f $packageDir/scripts/run-proton.sh
      test -f $packageDir/docs/desynced-in-isolated-display.jpg
    '';

    # Binaries the plugin resolves through PATH at runtime (its which() only
    # looks at PATH, and dsh pins passthru.runtimeDeps onto the launcher PATH).
    runtimeDeps = [
      pkgs.bash
      pkgs.grim
      pkgs.imagemagick
      pkgs.procps
      pkgs.pulseaudio
      pkgs.sway
      pkgs.tigervnc
      pkgs.wayvnc
      pkgs.x11vnc
      pkgs.xdotool
      pkgs.xdpyinfo
      pkgs.xwininfo
      pkgs.xvfb
      pkgs.xwayland
    ];

    passthru = {
      aiProvenance = [
        {
          agent = "dsh";
          model = "deepseek-flash";
          involvement = "assisted";
        }
      ];
      updateScript = nix-update-script {
        attrPath = "dsh-headless-display";
        extraArgs = [ "--flake" ];
      };
    };

    meta = {
      description = "Isolated headless X display for DeepSeek Harness with GPU-capable sway backend, silent audio and remote operation tools";
      homepage = "https://github.com/jingyingruodi/dsh-headless-display";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.linux;
    };
  })
