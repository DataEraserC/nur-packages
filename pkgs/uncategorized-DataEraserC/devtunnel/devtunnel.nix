{
  lib,
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  fetchurl,
  versionCheckHook,
  icu,
  openssl,
  darwin,
  ...
}:
let
  SupportedPlatforms = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];
  HostPlatform = stdenv.hostPlatform.system;
  version = "1.0.2115+e16833f284";

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/linux-x64-devtunnel";
        hash = "sha256-cj1q69wiYGSu8yElj7F8iidwycwr0FAEwPuD5yswLD8=";
      };
      aarch64-linux = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/linux-arm64-devtunnel";
        hash = "sha256-tTfycKVdV/I7diHOwLCYBqqa2hGXE7M+klUoQXm3a94=";
      };
      x86_64-darwin = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/osx-x64-devtunnel";
        hash = "sha256-OeXL+7WyGpTxS/oVANflMdyQrgR7/pYUbE4Fq1rkoYw=";
      };
      aarch64-darwin = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/osx-arm64-devtunnel";
        hash = "sha256-fKyaI8u158F7M9OLmSHIsMEIM3UzmAvbJNVsDG5LVP4=";
      };
    }
    .${HostPlatform};
in
stdenv.mkDerivation {
  pname = "devtunnel";
  inherit version src;

  passthru.updateScript = [ (toString ./update.sh) ];

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [
      autoPatchelfHook
      makeWrapper
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      darwin.sigtool
    ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    icu
    openssl
  ];

  installPhase = ''
    runHook preInstall
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      install -Dm755 $src $out/libexec/devtunnel
      makeWrapper $out/libexec/devtunnel $out/bin/devtunnel \
        --prefix LD_LIBRARY_PATH : ${
          lib.makeLibraryPath [
            icu
            openssl
          ]
        }
    ''}
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      install -Dm755 $src $out/bin/devtunnel
      codesign --force --sign - $out/bin/devtunnel
    ''}
    runHook postInstall
  '';

  nativeInstallCheckInputs = lib.optionals stdenv.hostPlatform.isLinux [
    versionCheckHook
  ];
  doInstallCheck = stdenv.hostPlatform.isLinux;
  versionCheckProgram = "${placeholder "out"}/bin/devtunnel";
  versionCheckProgramArg = "--version";

  meta = with lib; {
    # pls persist ~/.net/devtunnel folder
    description = "Microsoft Dev Tunnels CLI for securely exposing local services to the internet";
    homepage = "https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/";
    license = licenses.unfree;
    maintainers = import ../maintainers.nix;
    mainProgram = "devtunnel";
    platforms = SupportedPlatforms;
  };
}
