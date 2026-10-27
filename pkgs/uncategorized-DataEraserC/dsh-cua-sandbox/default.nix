# dsh-cua-sandbox — sandboxed desktop control for DeepSeek Harness via `cua mcp`.
#
# A dsh bundle that mounts the kernel's own generic MCP client plugin
# (@deepseek-ai/dsh-mcp-client) against the `cua` CLI's MCP server. The model
# gets two tool families under mcp__cua-mcp__*:
#
#   - sandbox_*   lifecycle: create / list / get / start / stop / restart /
#                 suspend / delete / view / vnc / open_browser
#   - computer_*  desktop control of the sandbox named per call (the `sandbox`
#                 param, default CUA_SANDBOX): screenshot, click, type, key,
#                 shell, file IO, windows, accessibility tree
#
# This is deliberately NOT the same thing as dsh-cua-driver: that bundle drives
# THIS machine's session through the harness's computerUse exclusive slot,
# while every call here lands inside a container "computer" — a disposable
# Podman/Docker image run by cua-vmm (gVisor/runc, QEMU, Lume). An agent that
# needs to try something risky gets a sandbox, not the user's desktop.
#
# No wrapper plugin JS: the insert row targets the kernel's mcp-client
# directly, whose Config schema already covers command/args/env/stdio. That
# also makes the pair version-matched to the kernel by construction — there is
# nothing to re-pin on a harness bump (unlike dsh-cua-driver's cohort glob).
#
# runtimeDeps pins the Nix-built cua-cli (sibling package) onto the dsh
# launcher PATH, which is how `command: cua` resolves. The spawned `cua mcp`
# inherits the scrubbed parent env plus the row's env:, and finds the rootless
# Podman engine socket among cua-vmm's well-known candidates
# ($XDG_RUNTIME_DIR/podman/podman.sock). Startup does not need the engine —
# sandbox_list works, per-call engine errors surface only on use.
#
# Bundle version tracks the cua-cli it drives; bump both on a new cua-sdk-v*
# tag (the skills ship inside cua-cli).
{
  lib,
  pkgs,
  inputs ? null,
  cua-cli,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-cua-sandbox requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-cua-sandbox)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-cua-sandbox";
    inherit (cua-cli) version;

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

      packageDir=$out/lib/node_modules/dsh-cua-sandbox
      mkdir -p $packageDir
      cp package.json cordis.patch.yml $packageDir/

      runHook postInstall
    '';

    postInstall = ''
      packageDir=$out/lib/node_modules/dsh-cua-sandbox
      test -f $packageDir/package.json
      test -f $packageDir/cordis.patch.yml
      grep -q "serverName: cua-mcp" $packageDir/cordis.patch.yml
    '';

    # cua must be on the dsh launcher PATH for `command: cua`; the kernel link
    # gives this bundle package the kernel's single cordis / schemastery /
    # mcp-client instances.
    runtimeDeps = [ cua-cli ];
    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      aiProvenance = [
        {
          agent = "workbuddy";
          model = "step-5-preview";
          involvement = "authored";
        }
      ];
      # The nix version is inherited from cua-cli and follows the upstream
      # cua-sdk-v* tag automatically; nix-update cannot evaluate this bundle
      # (flake inputs, no fetchable src), so update.sh syncs package.json's
      # version from the upstream tag list directly.
      updateScript = [ (toString ./update.sh) ];
    };

    meta = {
      description = "Sandboxed desktop control for DeepSeek Harness through the cua CLI MCP server";
      homepage = "https://github.com/trycua/cua";
      changelog = "https://github.com/trycua/cua/releases?q=cua-sdk";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.linux;
    };
  })
