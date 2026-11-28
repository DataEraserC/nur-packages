{
  lib,
  stdenv,
  makeWrapper,
  nodejs_24,
  zcode,
  zcode-tui,
}:
stdenv.mkDerivation {
  pname = "zcode-cli";
  inherit (zcode) version;
  __structuredAttrs = true;
  strictDeps = true;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/zcode-cli $out/bin
    cp -r ${zcode.contents}/resources/glm $out/share/zcode-cli/glm
    # The desktop-agent bundle inside the AppImage does not carry the provider
    # assets (resources/config/provider); the CLI resolves them from
    # glm/provider at startup, so copy them in.
    chmod -R u+w $out/share/zcode-cli/glm
    cp -r ${zcode.contents}/resources/config/provider $out/share/zcode-cli/glm/provider
    # zcode.cjs imports @zcode/tui when it is not running as a Node SEA; the
    # AppImage does not ship that package, so the server archive's TUI bundle
    # and its runtime deps are linked here.
    ln -s ${zcode-tui}/lib/node_modules $out/share/zcode-cli/glm/node_modules
    # Named zcode-cli, not zcode: the desktop package owns bin/zcode (its GUI
    # launcher), and this command must be resolvable on PATH next to it.
    makeWrapper ${lib.getExe nodejs_24} $out/bin/zcode-cli \
      --add-flags "$out/share/zcode-cli/glm/zcode.cjs" \
      --set NODE_ENV production
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    local output
    output=$($out/bin/zcode-cli --version)
    [ -n "$output" ] || {
      echo "zcode-cli --version produced no output" >&2
      exit 1
    }
    echo "zcode CLI version: $output"
    runHook postInstallCheck
  '';

  meta = {
    description = "ZCode coding agent CLI bundled in the Z.ai desktop app";
    homepage = "https://zcode.z.ai/";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = import ../maintainers.nix;
    mainProgram = "zcode-cli";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
