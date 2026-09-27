{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  libnotify,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-notifier requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-notifier)"
else
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-notifier";
    version = "0.13.1";

    src = fetchFromGitHub {
      owner = "THEWOLFWALKER";
      repo = "dsh-notifier";
      tag = "v${finalAttrs.version}";
      hash = "sha256-nrLC1nrdZC3TWf+ZQMfdkGS/yy6CpOjvfbg0ItXZw6E=";
    };

    npmDepsHash = "sha256-wXu1j29NFl+8J0pyM6AU/SeG618g98qoxNCQivw2GG8=";

    dontNpmBuild = true;

    postPatch = ''
      cp ${./package-lock.json} package-lock.json
      chmod u+w package-lock.json
    '';

    doCheck = true;

    checkPhase = ''
      runHook preCheck
      npm test
      runHook postCheck
    '';

    doInstallCheck = true;

    installCheckPhase = ''
      runHook preInstallCheck
      installedVersion=$(node -p "require('$out/lib/node_modules/dsh-notifier/package.json').version")
      test "$installedVersion" = "${finalAttrs.version}"
      runHook postInstallCheck
    '';

    postInstall = ''
      test -f $out/lib/node_modules/dsh-notifier/src/plugin-entry.mjs
      test -f $out/lib/node_modules/dsh-notifier/client.js
      test -f $out/lib/node_modules/dsh-notifier/cordis.patch.yml
    '';

    runtimeDeps = [ libnotify ];
    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

    passthru = {
      aiProvenance = [
        {
          agent = "dsh";
          model = "mimo-v2.6-flash-free";
          involvement = "authored";
        }
      ];
      updateScript = [ (toString ./update.sh) ];
    };

    meta = {
      changelog = "https://github.com/THEWOLFWALKER/dsh-notifier/blob/main/CHANGELOG.md";
      description = "Notification and remote-control plane for DeepSeek Harness with 28 outbound channels, 6 inbound control channels and a native Notify & Control UI";
      homepage = "https://github.com/THEWOLFWALKER/dsh-notifier";
      license = lib.licenses.mit;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
