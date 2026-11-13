{
  lib,
  stdenv,
  makeWrapper,
  nodejs_24,
  zcode,
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
