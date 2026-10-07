{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "m365-copilot2api";
  version = "0.7.3";
  src = fetchFromGitHub {
    owner = "HEXUXIU";
    repo = "M365-Copilot2API";
    tag = "v${finalAttrs.version}";
    hash = "sha256-oEnDWTqWmoVebDUoUEI76S3/77nFfgnxTUlBphBKMJg=";
  };

  vendorHash = "sha256-FACvdzONqBcnQyF2b2u4lNC2MyxxBRX79H0r7jq6QNc=";

  proxyVendor = true;

  subPackages = [ "cmd/server" ];

  ldflags = [
    "-s"
    "-w"
  ];

  postInstall = ''
    cp -r ${finalAttrs.src}/web $out/bin/web
  '';

  doCheck = false;

  passthru.updateScript = nix-update-script { };

  passthru.aiProvenance = [
    {
      agent = "dsh";
      involvement = "assisted";
    }
  ];

  meta = {
    changelog = "https://github.com/HEXUXIU/M365-Copilot2API/releases/tag/v${finalAttrs.version}";
    description = "Microsoft 365 Copilot to OpenAI/Anthropic compatible API gateway";
    homepage = "https://github.com/HEXUXIU/M365-Copilot2API";
    license = lib.licenses.agpl3Only;
    maintainers = import ../maintainers.nix;
    mainProgram = "server";
  };
})
