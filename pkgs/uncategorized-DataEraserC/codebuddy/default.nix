{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
}:
let
  release = builtins.fromJSON (builtins.readFile ./release.json);
  source =
    release.${stdenv.hostPlatform.system}
      or (throw "codebuddy: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "codebuddy";
  inherit (release) version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    inherit (source) url hash;
  };

  sourceRoot = ".";

  # Bun-compiled single-file executables keep their payload outside ELF
  # sections; stripping removes it and turns them into the bare Bun CLI.
  dontStrip = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 codebuddy $out/bin/codebuddy
    install -Dm644 LICENSE.txt $out/share/doc/codebuddy/LICENSE.txt
    install -Dm644 README.md $out/share/doc/codebuddy/README.md
    install -Dm644 CHANGELOG.md $out/share/doc/codebuddy/CHANGELOG.md
    runHook postInstall
  '';

  passthru = {
    updateScript = [ (toString ./update.sh) ];
    aiProvenance = [
      {
        agent = "dsh";
        model = "deepseek-v4-flash";
        involvement = "authored";
      }
    ];
  };

  meta = {
    description = "Terminal AI coding assistant from Tencent CodeBuddy";
    homepage = "https://cnb.cool/codebuddy/codebuddy-code";
    license = lib.licenses.unfree;
    mainProgram = "codebuddy";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maintainers = import ../maintainers.nix;
  };
})
