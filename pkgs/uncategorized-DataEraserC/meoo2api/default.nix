{
  lib,
  buildGoModule,
  fetchFromGitHub,
  unstableGitUpdater,
}:
buildGoModule (finalAttrs: {
  pname = "meoo2api";
  version = "0-unstable-2026-11-12";
  src = fetchFromGitHub {
    owner = "LazyBonesLZY";
    repo = "meoo2api";
    rev = "e0183ac0981d07c6a916c2fc81716db5d9e8cdc7";
    hash = "sha256-FEwrSd7nw0GEZ7xEDXP35hOi+GzbuN+n3skAe13qyj8=";
  };
  __structuredAttrs = true;
  strictDeps = true;
  vendorHash = null;

  subPackages = [ "cmd/server" ];

  ldflags = [
    "-s"
    "-w"
  ];

  postInstall = ''
    mv $out/bin/server $out/bin/meoo2api
  '';

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/LazyBonesLZY/meoo2api.git";
    hardcodeZeroVersion = true;
  };

  passthru.aiProvenance = [
    {
      agent = "TraeCode";
      model = "DeepSeek-V4.1-Flash";
      involvement = "authored";
    }
  ];

  meta = {
    description = "Meoo model gateway proxy with an OpenAI compatible API and account console";
    homepage = "https://github.com/LazyBonesLZY/meoo2api";
    license = lib.licenses.mit;
    mainProgram = "meoo2api";
    maintainers = import ../maintainers.nix;
  };
})
