{
  pkgs,
  inputs ? null,
}:
if inputs == null then
  throw "dsh-content-extractor requires the content-extractor flake input; evaluate it through the flake (nix build .#dsh-content-extractor)"
else
  # The content-extractor flake builds both halves itself — extractor-abi behind
  # the C ABI and the DSH host under hosts/dsh/ that installs it at
  # native/libextractor.so — so re-export instead of repeating the recipe. Same
  # shape as bas-remote: no hash to refresh per release, and the library and
  # the host cannot drift apart.
  (inputs.content-extractor.packages.${pkgs.stdenv.hostPlatform.system}.dsh.overrideAttrs (old: {
    passthru = (old.passthru or { }) // {
      # meta.position of a re-export points into the input's store path, which
      # hides the package from tools/build_own_cachix.py's path filter. This
      # marker is how that filter recognises own-group packages re-exported
      # from a flake input.
      ownPackage = true;
      # yt-dlp / ffmpeg are spawned by the plugin; keep declaring them so the
      # dsh launcher PATH keeps carrying them for this bundle. The non-video
      # extractors (articles, posts, replays, direct files) use plain HTTP and
      # need nothing extra.
      runtimeDeps = [
        pkgs.yt-dlp
        pkgs.ffmpeg
      ];
    };
    meta = (old.meta or { }) // {
      changelog = "https://github.com/DataEraserC/content-extractor/releases";
      maintainers = import ../maintainers.nix;
    };
  }))
