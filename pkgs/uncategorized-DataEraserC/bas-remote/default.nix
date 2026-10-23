{
  pkgs,
  inputs ? null,
}:
if inputs == null then
  throw "bas-remote requires the bas-remote flake input; evaluate it through the flake (nix build .#bas-remote)"
else
  # The upstream flake builds both halves itself — the Rust library behind the C
  # ABI and the DSH host that installs it at native/libbas_api.so — against the
  # same deepseek-harness this repository pins (the input follows it). Re-export
  # instead of repeating the recipe, so the two cannot drift and no hash has to
  # be refreshed per release.
  (inputs.bas-remote.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    passthru = (old.passthru or { }) // {
      # meta.position of a re-export points into the input's store path, which
      # hides the package from tools/build_own_cachix.py's path filter. This
      # marker is how that filter recognises own-group packages re-exported
      # from a flake input.
      ownPackage = true;
    };
    meta = (old.meta or { }) // {
      changelog = "https://github.com/DataEraserC/bas-remote/blob/main/CHANGELOG.md";
      maintainers = import ../maintainers.nix;
    };
  }))
