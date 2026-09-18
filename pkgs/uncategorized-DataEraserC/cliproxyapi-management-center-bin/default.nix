{
  lib,
  stdenv,
  fetchurl,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "cliproxyapi-management-center-bin";
  version = "1.24.0";
  src = fetchurl {
    url = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/download/v${finalAttrs.version}/management.html";
    hash = "sha256-kLNPgLy+fIR7TDtbt5FT+1vKtwfhkIm1V8i8TdvoZ/Q=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm644 $src $out/management.html
    ln -s management.html $out/index.html

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };
  passthru.aiProvenance = [
    {
      agent = "dsh";
      model = "deepseek-v4-flash";
      involvement = "authored";
    }
  ];

  meta = {
    description = "Prebuilt web management interface for CLIProxyAPI";
    homepage = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.all;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
