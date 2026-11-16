{
  pkgs,
  inputs ? null,
}:
if inputs == null then
  throw "dsh-video-fetch requires the video-login flake input; evaluate it through the flake (nix build .#dsh-video-fetch)"
else
  # The video-login flake builds both halves itself — vlogin-abi behind the C
  # ABI and the DSH host under hosts/dsh/ that installs it at
  # native/libvlogin.so — so re-export instead of repeating the recipe. Same
  # shape as bas-remote: no hash to refresh per release, and the library and
  # the host cannot drift apart.
  (inputs.video-login.packages.${pkgs.stdenv.hostPlatform.system}.dsh.overrideAttrs (old: {
    passthru = (old.passthru or { }) // {
      # meta.position of a re-export points into the input's store path, which
      # hides the package from tools/build_own_cachix.py's path filter. This
      # marker is how that filter recognises own-group packages re-exported
      # from a flake input.
      ownPackage = true;
      # yt-dlp / ffmpeg are spawned by the plugin; keep declaring them so the
      # dsh launcher PATH keeps carrying them for this bundle.
      runtimeDeps = [
        pkgs.yt-dlp
        pkgs.ffmpeg
      ];
    };
    meta = (old.meta or { }) // {
      changelog = "https://github.com/DataEraserC/video-login/releases";
      maintainers = import ../maintainers.nix;
    };
  }))
