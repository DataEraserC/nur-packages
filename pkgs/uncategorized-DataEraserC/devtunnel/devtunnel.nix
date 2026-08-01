{
  lib,
  stdenv,
  autoPatchelfHook,
  makeWrapper,
  sources,
  versionCheckHook,
  icu,
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
  source =
    if lib.elem HostPlatform SupportedPlatforms then
      sources."AAA_devtunnel-${HostPlatform}"
    else
      throw "Unsupported platform: ${HostPlatform}";
in
stdenv.mkDerivation {
  inherit (source) pname version src;

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
  ];

  installPhase = ''
    runHook preInstall
    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      install -Dm755 $src $out/libexec/devtunnel
      makeWrapper $out/libexec/devtunnel $out/bin/devtunnel \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ icu ]}
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
    description = "Microsoft Dev Tunnels CLI for securely exposing local services to the internet";
    homepage = "https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/";
    license = licenses.unfree;
    maintainers = with maintainers; [ xddxdd ];
    mainProgram = "devtunnel";
    platforms = SupportedPlatforms;
  };
}
