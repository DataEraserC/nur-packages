{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
}:
{
  pname,
  executable,
  releaseJson,
  description,
  homepage,
  updateScript,
}:
let
  release = builtins.fromJSON (builtins.readFile releaseJson);
  source =
    release.${stdenv.hostPlatform.system}
      or (throw "${pname}: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  inherit pname;
  inherit (release) version;

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    inherit (source) url hash;
  };

  sourceRoot = ".";

  dontStrip = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ${executable} $out/bin/${executable}
    runHook postInstall
  '';

  passthru = {
    updateScript = [ (toString updateScript) ];
    aiProvenance = [
      {
        agent = "qoder";
        involvement = "authored";
      }
    ];
  };

  meta = {
    inherit description homepage;
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = executable;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maintainers = import ./maintainers.nix;
  };
}
