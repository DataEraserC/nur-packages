{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  yt-dlp,
  ffmpeg,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-video-fetch requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-video-fetch)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-video-fetch";
    version = "0.1.2";

    src = fetchFromGitHub {
      owner = "DataEraserC";
      repo = "dsh-video-fetch";
      # Follow the release tag; update.sh bumps version, src hash and
      # npmDepsHash together (the lockfile ships inside the tag).
      rev = "v${finalAttrs.version}";
      hash = "sha256-KshxxqbhqWMyWk1Jq/e+OyvrhNeSJmB11LBzfTA8IPc=";
    };

    npmDepsHash = "sha256-pWerSrDjSd173wbTWlNiIsQQ+U5VmMVIkSTP4REZdpE=";

    dontNpmBuild = true;

    # Unit tests are offline: they only use $TMPDIR and a DSH_HOME they set themselves.
    doCheck = true;
    checkPhase = ''
      runHook preCheck

      node --test test/*.test.js

      runHook postCheck
    '';

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    # spawn('yt-dlp') / spawn('ffmpeg') from the plugin; the dsh base bundle has neither.
    runtimeDeps = [
      yt-dlp
      ffmpeg
    ];

    postInstall = ''
      test -f $out/lib/node_modules/dsh-video-fetch/lib/index.js
    '';

    passthru = {
      updateScript = [ (toString ./update.sh) ];
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.6-flash-free";
          involvement = "authored";
        }
      ];
    };

    meta = {
      description = "Video downloading for DeepSeek Harness with per-site login (bilibili QR / cookie import) and ffmpeg compression";
      homepage = "https://github.com/DataEraserC/dsh-video-fetch";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
