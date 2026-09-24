{
  fetchFromGitHub,
  lib,
  nix-update-script,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "mimocode2api";
  version = "0.2.0";
  src = fetchFromGitHub {
    owner = "wx8472235-cell";
    repo = "mimocode2api";
    tag = "v${finalAttrs.version}";
    hash = "sha256-reKtTZqnqtnSfgAkTD1g2wo+4wVmPB1wF40A+X22TpE=";
  };
  cargoHash = "sha256-W61JxxiZS2MqgjWFyowAQ9ulQZU6CGMawTlXRplt+vY=";

  passthru.updateScript = nix-update-script { };
  passthru.aiProvenance = [
    {
      agent = "dsh";
      model = "mimo-v2.6-flash-free";
      involvement = "authored";
    }
  ];

  meta = {
    changelog = "https://github.com/wx8472235-cell/mimocode2api/releases/tag/v${finalAttrs.version}";
    description = "Converts Xiaomi MiMo Code built-in free models into an OpenAI-compatible API without API keys";
    homepage = "https://github.com/wx8472235-cell/mimocode2api";
    license = lib.licenses.mit;
    mainProgram = "mimocode2api";
    maintainers = import ../maintainers.nix;
  };
})
