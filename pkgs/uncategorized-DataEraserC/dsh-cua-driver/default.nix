# dsh-cua-driver — computer use for DeepSeek Harness via the Cua Driver.
#
# A dsh bundle (cordis plugin manifest) that mounts the harness's own
# experimental Cua Driver MCP provider:
#
#   - @deepseek-ai/dsh-computer-use                      (exclusive provider slot)
#   - @deepseek-ai/dsh-experimental-computer-use-cua-driver-mcp
#       config: { command: cua-driver, args: [mcp] }
#
# Both packages ship inside this bundle because the dsh kernel deploys only
# its own dependency closure, which does not include them. They are prebuilt
# npm tarballs pinned to the harness version (see the assert below); their
# peers (cordis, schemastery, dsh-mcp-client, dsh-brand) are NOT shipped —
# linkKernelNodeModules links the kernel's node_modules into each package so
# every peer resolves to the kernel's single instance.
#
# runtimeDeps pins the Nix-built cua-driver (this repo's sibling package) onto
# the dsh launcher PATH, which is how `command: cua-driver` resolves at MCP
# spawn time. On Linux the spawned `cua-driver mcp` owns a direct runtime and
# inherits DISPLAY / WAYLAND_DISPLAY from the dsh process.
#
# Bundle version tracks the cua-driver it drives; the @deepseek-ai provider
# pair tracks the dsh kernel (pinned by the assert). Bump all three together:
# cua-driver (sibling package) for a new driver release, and the two hashes
# here when deepseek-harness.nix moves.
{
  lib,
  pkgs,
  inputs ? null,
  fetchurl,
  nix-update-script,
  cua-driver,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
  dshVersion = dshPkgs.dsh.dsh-kernel.version;

  # The provider packages are published per dsh release; the hashes below
  # belong to exactly this version. A harness bump trips the assert with a
  # message instead of a cryptic fixed-output hash mismatch.
  pinnedDshVersion = "0.2.1-rc.2";
  computerUse = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh-computer-use/-/dsh-computer-use-${dshVersion}.tgz";
    hash = "sha256-bgm8Fn9tBxHW4k0rwsenTDtfhHJd8bvJeDuBZ4lujpc=";
  };
  cuaDriverMcp = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh-experimental-computer-use-cua-driver-mcp/-/dsh-experimental-computer-use-cua-driver-mcp-${dshVersion}.tgz";
    hash = "sha256-WilVAvwKO0FEEezSXnjycpLoRKFHffzfyvgzryj4REE=";
  };
in
if inputs == null then
  throw "dsh-cua-driver requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-cua-driver)"
else if dshVersion != pinnedDshVersion then
  throw ''
    dsh-cua-driver: the pinned @deepseek-ai provider packages target dsh ${pinnedDshVersion},
    but the deepseek-harness input is ${dshVersion}. Fetch the matching npm
    versions and re-pin computerUse/cuaDriverMcp hashes.
  ''
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

      # The two provider packages, prebuilt, peers resolved from the kernel
      # via linkKernelNodeModules below.
      mkdir -p $out/lib/node_modules/@deepseek-ai/dsh-computer-use
      tar xzf ${computerUse} --strip-components=1 \
        -C $out/lib/node_modules/@deepseek-ai/dsh-computer-use
      mkdir -p $out/lib/node_modules/@deepseek-ai/dsh-experimental-computer-use-cua-driver-mcp
      tar xzf ${cuaDriverMcp} --strip-components=1 \
        -C $out/lib/node_modules/@deepseek-ai/dsh-experimental-computer-use-cua-driver-mcp

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
      updateScript = nix-update-script {
        attrPath = "dsh-cua-driver";
        extraArgs = [
          "--version-regex"
          "^cua-driver-rs-v(.*)$"
        ];
      };
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
