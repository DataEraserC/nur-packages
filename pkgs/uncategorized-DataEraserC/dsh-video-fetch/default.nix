{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  video-login-abi,
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
    version = "0.5.0";

    src = fetchFromGitHub {
      owner = "DataEraserC";
      repo = "dsh-video-fetch";
      # Follow the release tag; update.sh bumps version, src hash and
      # npmDepsHash together (the lockfile ships inside the tag).
      rev = "v${finalAttrs.version}";
      hash = "sha256-f6r49hWDJnQJJQcDHqUcIBsnpN+ATSYON9KjYhm44Mw=";
    };

    npmDepsHash = "sha256-XGaMRfO+3cOmDYwNloTjuc3jycxquxnfsqKTP5mXfAo=";

    dontNpmBuild = true;

    preCheck = ''
      mkdir -p native
      cp ${video-login-abi}/lib/libvlogin.so native/libvlogin.so
    '';

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

      mkdir -p $out/lib/node_modules/dsh-video-fetch/native
      cp ${video-login-abi}/lib/libvlogin.so $out/lib/node_modules/dsh-video-fetch/native/libvlogin.so
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
      description = "Video downloading for DeepSeek Harness with per-channel login (QR / cookie / SMS / password / browser) and ffmpeg compression";
      homepage = "https://github.com/DataEraserC/dsh-video-fetch";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
