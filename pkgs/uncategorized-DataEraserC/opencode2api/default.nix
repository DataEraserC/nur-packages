{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "opencode2api";
  version = "1.3.0";
  src = fetchFromGitHub {
    owner = "jasonxu114514";
    repo = "opencode2api";
    tag = "v${finalAttrs.version}";
    hash = "sha256-dnLorUG552RWHx7kx/zm5d1jPb2pIu+850kCFc8OWek=";
  };
  vendorHash = "sha256-W8Ou22mK6IGDKsS92SlgQj3iYRCF5F4O/s6uUG54y34=";

  proxyVendor = true;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${finalAttrs.version}"
  ];

  subPackages = [ "cmd/opencode2api" ];

  doCheck = false;

  postInstall = ''
    install -Dm644 ${finalAttrs.src}/config.example.json $out/share/doc/opencode2api/config.example.json
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    changelog = "https://github.com/jasonxu114514/opencode2api/releases/tag/v${finalAttrs.version}";
    description = "OpenCode Zen and Zen Go API gateway with OpenAI and Anthropic compatibility, key pooling, and WebUI";
    homepage = "https://github.com/jasonxu114514/opencode2api";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ DataEraserC ];
    mainProgram = "opencode2api";
  };
})
