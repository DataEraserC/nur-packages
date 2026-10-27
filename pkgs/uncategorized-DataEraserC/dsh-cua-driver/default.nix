# dsh-cua-driver — computer use for DeepSeek Harness via the Cua Driver.
#
# A dsh bundle (cordis plugin manifest) that mounts the harness's own
# experimental Cua Driver MCP provider:
#
#   - @deepseek-ai/dsh-computer-use                      (exclusive provider slot)
#   - @deepseek-ai/dsh-experimental-computer-use-cua-driver-mcp
#       config: { command: cua-driver, args: [mcp] }
#
# Everything the provider runs is upstream's: the two packages are unpacked
# straight from the harness workspace's cohort output (the `pnpm pack` release
# set of deepseek-ai/deepseek-harness — the same derivation that builds the
# kernel), and the composition rows are the recipe from the provider's own
# README. The dsh kernel deploys only its own dependency closure, which
# excludes both packages, so this bundle is the Nix vehicle that puts them on
# disk; upstream itself ships no bundle for them (no dsh.bundle.patch).
#
# runtimeDeps pins the Nix-built cua-driver (this repo's sibling package) onto
# the dsh launcher PATH, which is how `command: cua-driver` resolves at MCP
# spawn time. On Linux the spawned `cua-driver mcp` owns a direct runtime and
# inherits DISPLAY / WAYLAND_DISPLAY from the dsh process.
#
# Bundle version tracks the cua-driver it drives. Bump it together with the
# sibling cua-driver package on a new cua-driver-rs-v* tag; the provider pair
# needs no manual bump — the cohort glob follows the harness automatically.
{
  lib,
  pkgs,
  inputs ? null,
  cua-driver,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
  # The harness workspace's release set: one pnpm-packed tarball per workspace
  # package, built by the same derivation as the kernel, so the provider
  # packages are version-matched to the kernel by construction.
  cohort = dshPkgs.dsh.dsh-workspace.cohort;
in
if inputs == null then
  throw "dsh-cua-driver requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-cua-driver)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-cua-driver";
    inherit (cua-driver) version;

    src = ./.;

    # Data-only bundle: nothing for npm to install or build. Overriding
    # npmConfigHook with an empty directory skips the hook entirely (null
    # would restore the default hook, which insists on npmDeps plus a
    # package-lock.json).
    npmDeps = null;
    npmConfigHook = pkgs.emptyDirectory;
    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      packageDir=$out/lib/node_modules/dsh-cua-driver
      mkdir -p $packageDir
      cp package.json cordis.patch.yml $packageDir/

      # Unpack the two upstream provider packages from the harness cohort.
      # pnpm pack layout: every file sits under package/ inside the tarball.
      # A glob rather than a pinned filename: a harness bump follows
      # automatically, and a renamed or removed package fails the build here
      # instead of silently mounting a stale provider. Exactly one match per
      # package is required — the experimental package's name starts with
      # deepseek-ai-dsh-experimental-, so the two globs stay disjoint.
      cohort=${cohort}
      unpack_provider() {
        local prefix=$1 dest=$2
        local matches=("$cohort"/''${prefix}-*.tgz)
        if [ "''${#matches[@]}" -ne 1 ] || [ ! -f "''${matches[0]}" ]; then
          printf 'dsh-cua-driver: expected exactly one %s-*.tgz in the cohort output\n' "$prefix" >&2
          exit 1
        fi
        mkdir -p "$out/lib/node_modules/@deepseek-ai/$dest"
        tar xzf "''${matches[0]}" --strip-components=1 \
          -C "$out/lib/node_modules/@deepseek-ai/$dest"
      }
      unpack_provider deepseek-ai-dsh-computer-use dsh-computer-use
      unpack_provider deepseek-ai-dsh-experimental-computer-use-cua-driver-mcp \
        dsh-experimental-computer-use-cua-driver-mcp

      runHook postInstall
    '';

    postInstall = ''
      packageDir=$out/lib/node_modules/dsh-cua-driver
      test -f $packageDir/package.json
      test -f $packageDir/cordis.patch.yml
      test -f $out/lib/node_modules/@deepseek-ai/dsh-computer-use/lib/index.js
      test -f $out/lib/node_modules/@deepseek-ai/dsh-experimental-computer-use-cua-driver-mcp/lib/index.js
    '';

    # cua-driver must be on the dsh launcher PATH for `command: cua-driver`;
    # the kernel link gives both provider packages (and this bundle package)
    # the kernel's single cordis/schemastery/mcp-client instances.
    runtimeDeps = [ cua-driver ];
    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      aiProvenance = [
        {
          agent = "workbuddy";
          model = "step-5-preview";
          involvement = "authored";
        }
      ];
      # The nix version is inherited from cua-driver and follows the upstream
      # cua-driver-rs-v* tag automatically; nix-update cannot evaluate this
      # bundle (flake inputs, no fetchable src), so update.sh syncs
      # package.json's version from the upstream tag list directly.
      updateScript = [ (toString ./update.sh) ];
    };

    meta = {
      description = "Computer use for DeepSeek Harness through an installed Cua Driver MCP executable";
      homepage = "https://github.com/trycua/cua";
      changelog = "https://github.com/trycua/cua/releases?q=cua-driver-rs";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.linux;
    };
  })
