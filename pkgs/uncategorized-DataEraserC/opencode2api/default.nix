{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule (finalAttrs: {
  pname = "opencode2api";
  version = "1.3.3";
  src = fetchFromGitHub {
    owner = "jasonxu114514";
    repo = "opencode2api";
    tag = "v${finalAttrs.version}";
    hash = "sha256-o5m5FEL9EEkzMKI6XYU4FEYtfM7cTScI3bFO43a2ZEg=";
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
    maintainers = import ../maintainers.nix;
    mainProgram = "opencode2api";
  };
})
