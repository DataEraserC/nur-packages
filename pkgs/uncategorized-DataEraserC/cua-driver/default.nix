# cua-driver — the Rust MCP server / CLI from trycua/cua.
#
# Built from source following the upstream project's own Nix recipe
# (nix/cua-driver/package.nix in trycua/cua): the source tree is rooted at
# libs/cua-driver/rust because the cua-driver crate depends on
# libs/cua/crates/cua-telemetry by path, so the whole repository is fetched
# and only the driver workspace is compiled (-p cua-driver keeps the
# macOS/Windows-only member crates out of the Linux dependency graph).
#
# Both portal features are enabled on purpose (same as upstream's recipe):
# portal-input brings the GNOME/KDE libei RemoteDesktop input route and
# portal-capture brings PipeWire ScreenCast per-window capture, which is what
# a wlroots compositor (niri/sway/hyprland) needs. The shipped release
# binaries only carry portal-input.
#
# The version-matching agent skill pack is fetched from the same GitHub
# release and installed under $out/share/cua-driver-skills, so Nix can
# symlink it into an agent's skills directory (dsh: ~/.dsh/skills/cua-driver)
# without the driver's own `skills install` verb reaching into the network at
# runtime.
{
  lib,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  pkg-config,
  libx11,
  libxext,
  libxi,
  libxkbcommon,
  libxtst,
  libei,
  pipewire,
}:
let
  versionData = {
    # The tag that release-please cut for the driver, e.g. cua-driver-rs-v0.38.0.
    tag = "cua-driver-rs-v0.38.0";
    hash = "sha256-Fpryc6Vg9vtV3zRCaL4S38v8l4JluU95o86dQbzkDPM=";
    # cua-driver-rs-v<version>-skills.tar.gz from the same release; the asset
    # name keeps the legacy -rs suffix.
    skillsHash = "sha256-D+PWB+chLWxYByokGRYzQgYdz1y4m6EkPepZPX4zvg8=";
  };
  version = lib.removePrefix "cua-driver-rs-v" versionData.tag;
  src = fetchFromGitHub {
    owner = "trycua";
    repo = "cua";
    inherit (versionData) tag hash;
  };
  # The driver workspace lives under libs/ (see the header comment); the
  # version is read from the workspace manifest so it cannot drift.
  rustSrc = "${src}/libs/cua-driver/rust";
  # Packaged alongside the binary release: SKILL.md plus the platform deep
  # dives, pinned to the binary's own version by the release asset name.
  skills = fetchurl {
    url = "https://github.com/trycua/cua/releases/download/${versionData.tag}/${versionData.tag}-skills.tar.gz";
    hash = versionData.skillsHash;
  };
in
rustPlatform.buildRustPackage rec {
  pname = "cua-driver";
  inherit version src;

  # Vendor straight from the committed Cargo.lock (importCargoLock derives
  # every dependency hash from the lockfile itself, so there is no cargoHash
  # to hand-maintain across Cargo.lock changes).
  cargoLock.lockFile = "${rustSrc}/Cargo.lock";

  nativeBuildInputs = [
    pkg-config
    # bindgen needs a libclang for the libpipewire/libspa SPA pod codegen.
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    libx11
    libxext
    libxi
    libxtst
    libxkbcommon
    libei
    pipewire
  ];

  postUnpack = ''
    sourceRoot="$sourceRoot/libs/cua-driver/rust"
  '';

  # Mostly pure Rust (x11rb, ureq/rustls, tiny-skia, ring); the X11 crate
  # needs libX11/libXi/libXtst and the Wayland-parity work needs PipeWire,
  # libei (via reis) and libxkbcommon — all in buildInputs above.
  cargoBuildFlags = [
    "-p"
    "cua-driver"
    "--features"
    "portal-input,portal-capture"
  ];

  # Tests need a running X11 display and an AT-SPI bus.
  doCheck = false;

  # The default installPhase installs the binaries cargo built under
  # target/release; `-p cua-driver` above keeps that to the single driver
  # binary (the workspace's other members are macOS/Windows-only).
  postInstall = ''
    # Agent skill pack (SKILL.md + references), version-pinned to the binary
    # by the release asset name.
    mkdir -p $out/share/cua-driver-skills
    tar xzf ${skills} --strip-components=1 -C $out/share/cua-driver-skills
    test -f $out/share/cua-driver-skills/SKILL.md
  '';

  # The releases atom feed is flooded with nightly-cua-driver-rs-*/cua-spaces-*
  # tags and the version lives in versionData.tag, so nix-update cannot drive
  # this package; see update.sh.
  passthru.updateScript = [ (toString ./update.sh) ];

  meta = {
    description = "Cross-platform MCP server and CLI for computer-use automation (trycua/cua driver)";
    homepage = "https://github.com/trycua/cua";
    changelog = "https://github.com/trycua/cua/releases?q=cua-driver-rs";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    mainProgram = "cua-driver";
    platforms = lib.platforms.linux;
  };
}
