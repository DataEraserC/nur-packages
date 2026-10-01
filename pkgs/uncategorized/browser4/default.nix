{
  lib,
  makeWrapper,
  pkgs,
  stdenv,
  versionCheckHook,
  unwrapped ? pkgs.callPackage ../browser4-unwrapped { },
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "browser4";
  inherit (unwrapped) version;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgramArg = "--version";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    ln -s ${unwrapped}/bin/browser4-cli "$out/bin/browser4-cli"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/browser4-cli" \
      --set-default BROWSER4_CLI_FORCE_REMOTE_BUNDLE 1 \
      --set-default BROWSER4_RUNTIME_DIR ${unwrapped.runtime}/share/browser4 \
      --run 'd="''${BROWSER4_CLI_STATE_DIR:-''${HOME:+$HOME/.browser4}}"; if [ -n "$d" ] && [ ! -d "$d/logs" ]; then mkdir -p "$d/logs" || echo "browser4: warning: could not create logs directory $d/logs" >&2; fi' \
      --run 'case "''${BROWSER4_RUNTIME_DIR:-}" in ""|/nix/store/*) ;; *) echo "browser4: warning: BROWSER4_RUNTIME_DIR=$BROWSER4_RUNTIME_DIR points outside /nix/store; a runtime downloaded there is not patched for the NixOS dynamic linker and will likely fail to start" >&2 ;; esac' \
      --run 'export BROWSER4_SERVER_OPTS="-Dlogging.dir=''${BROWSER4_CLI_STATE_DIR:-''${HOME}/.browser4}/logs''${BROWSER4_SERVER_OPTS:+ ''${BROWSER4_SERVER_OPTS}}"' \
      --run 'tag_seen=0 cmd= takes_val=0; for arg in "$@"; do if [ "$takes_val" = 1 ]; then takes_val=0; continue; fi; case "$arg" in --session|--server|--proxy|--timeout|-s) takes_val=1 ;; --tag|--tag=*) tag_seen=1 ;; -*) ;; *) if [ -z "$cmd" ]; then cmd=$arg; fi ;; esac; done; if [ "$tag_seen" = 0 ] && { [ "$cmd" = install ] || [ "$cmd" = upgrade ]; }; then set -- "$@" --tag ${unwrapped.tag}; fi'
  '';

  passthru = {
    inherit unwrapped;
    inherit (unwrapped) runtime;
    inherit (unwrapped) tag;
  };

  meta = {
    description = "MCP-driven browser automation toolkit pairing a Rust command-line client with a Java automation server";
    homepage = "https://github.com/platonai/Browser4";
    changelog = "https://github.com/platonai/Browser4/releases";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ xddxdd ];
    mainProgram = "browser4-cli";
    platforms = [ "x86_64-linux" ];
  };
})
