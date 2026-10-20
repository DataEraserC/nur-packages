{
  stdenv,
  lib,
  fetchurl,
  autoPatchelfHook,
  glibc,
  gcc,
}:
let
  releaseBase = "https://github.com/DataEraserC/nur-packages/releases/download/bstar-0.5.10";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "bstar";
  version = "0.5.10";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchurl {
    url = "${releaseBase}/bstar-${finalAttrs.version}.so";
    hash = "sha256-I5ejRvQfSSutRcDavM2Uyc9l3W1JrdOq81cRe2pFWAw=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    glibc
    gcc.cc.lib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 ${finalAttrs.src} $out/lib/bstar-${finalAttrs.version}.so
    ln -svf $out/lib/bstar-${finalAttrs.version}.so $out/lib/libbstar.so
    runHook postInstall
  '';

  passthru = {
    # Same project, different build; it cannot drive the current QQ NT client,
    # so it is kept reachable but is deliberately not what the package installs.
    lightweightV8Inject = fetchurl {
      url = "${releaseBase}/liblightweight-v8-inject.so";
      hash = "sha256-X4/Aqmq2Vo13m/XwHqPwvrYyD39O7yyrRegclK9FgEQ=";
    };
    aiProvenance = [
      {
        agent = "dsh";
        model = "deepseek-v4.1-flash-sg";
        involvement = "assisted";
      }
    ];
  };

  meta = with lib; {
    maintainers = import ../maintainers.nix;
    description = "V8 injection library that adds ChronoCat support to the QQ NT client";
    homepage = "https://github.com/chrononeko/chronocat";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
})
