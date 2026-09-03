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
  version = "1.0.2030+fc9273aa0f";

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/linux-x64-devtunnel";
        hash = "sha256-/2kRVIkHtauupO1bqjayQgvnxd68tjek9Q96QAKxC2A=";
      };
      aarch64-linux = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/linux-arm64-devtunnel";
        hash = "sha256-96duARej6NW/v5QW40gM2sNsK0uxDSaD8HgNyShLZC8=";
      };
      x86_64-darwin = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/osx-x64-devtunnel";
        hash = "sha256-o0+Qa/u5lETsRaCEv6yAKEufORnIF0GoOLPqt146zfM=";
      };
      aarch64-darwin = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/osx-arm64-devtunnel";
        hash = "sha256-AE88yOvM5hIjusrIDTGTfrLpLq7poFYAocti+193Wv4=";
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
    maintainers = [ ];
    mainProgram = "devtunnel";
    platforms = SupportedPlatforms;
  };
}
