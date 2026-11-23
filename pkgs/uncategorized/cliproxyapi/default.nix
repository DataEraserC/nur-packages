{
  fetchFromGitHub,
  lib,
  buildGo127Module,
  nix-update-script,
}:
buildGo127Module (finalAttrs: {
  pname = "cliproxyapi";
  version = "8.1.1";
  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    tag = "v${finalAttrs.version}";
    hash = "sha256-/iX+8j1XltHsIeP7GafJdqslZ2bnmq4AlWSW042QpWA=";
  };
  __structuredAttrs = true;
  strictDeps = true;
  vendorHash = "sha256-VC+lOuWurhTLEnp5CiHxUF6Y6nB667VFK6WaGqez5uo=";

  proxyVendor = true;

  ldflags = [
    "-s"
    "-w"
  ];

  doCheck = false;

  passthru.updateScript = nix-update-script { };
  meta = {
    changelog = "https://github.com/router-for-me/CLIProxyAPI/releases/tag/v${finalAttrs.version}";
    maintainers = with lib.maintainers; [ xddxdd ];
    description = "Wrap Gemini CLI, Antigravity, ChatGPT Codex, Claude Code, Qwen Code, iFlow as an OpenAI/Gemini/Claude/Codex compatible API service";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "server";
  };
})
