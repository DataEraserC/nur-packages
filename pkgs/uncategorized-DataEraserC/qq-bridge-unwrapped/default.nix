{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nix-update-script,
}:

buildNpmPackage (finalAttrs: {
  pname = "qq-bridge-unwrapped";
  version = "0.1.7";

  src = fetchFromGitHub {
    owner = "Derpyu520";
    repo = "qq-bridge";
    # Follow the release tag, so nix-update only has to bump `version`.
    rev = "v${finalAttrs.version}";
    hash = "sha256-dA8cFHHsra/LE5cp6useKx4Tdq2mSJtPjNTHg7rWBmg=";
  };

  npmDepsHash = "sha256-2DqEtGAaCcpjPUsEWSLOl3mrGysuSyE5iBmzsdlUlH4=";

  npmFlags = [ "--legacy-peer-deps" ];

  dontNpmBuild = true;

  postInstall = ''
    test -f $out/lib/node_modules/qq-bridge/src/bridge.js
    test -f $out/lib/node_modules/qq-bridge/config.example.json
  '';

  passthru = {
    aiProvenance = [
      {
        agent = "dsh";
        model = "mimo-v2.5-free";
        involvement = "assisted";
      }
    ];
    updateScript = nix-update-script {
      attrPath = "qq-bridge-unwrapped";
      extraArgs = [ "--flake" ];
    };
  };

  meta = {
    description = "QQ (SnowLuma OneBot v11) bridge for DeepSeek Harness agents (unwrapped)";
    homepage = "https://github.com/Derpyu520/qq-bridge";
    license = lib.licenses.mit;
    maintainers = import ../maintainers.nix;
    platforms = lib.platforms.unix;
  };
})
