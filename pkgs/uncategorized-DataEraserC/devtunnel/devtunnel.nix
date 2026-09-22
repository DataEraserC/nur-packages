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
  version = "1.0.2094+24665e6583";

  src =
    {
      x86_64-linux = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/linux-x64-devtunnel";
        hash = "sha256-KqbEGq94QEJ+hLfh6ZvluCaplm/AJ932HcD2m2jbBgs=";
      };
      aarch64-linux = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/linux-arm64-devtunnel";
        hash = "sha256-76w3j5/7QJFJNfvSNhVDCItQzWIkg3LfBsJD5vfEnMg=";
      };
      x86_64-darwin = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/osx-x64-devtunnel";
        hash = "sha256-79ZztbNs0TD12X5ZElr+65XK6m1ka5L7aJHGiW97goI=";
      };
      aarch64-darwin = fetchurl {
        url = "https://tunnelsassetsprod.blob.core.windows.net/cli/${version}/osx-arm64-devtunnel";
        hash = "sha256-vnImzLsBeDgdbunK1AJ04p8OjpQFUHx9cO5l+MDqsk4=";
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
