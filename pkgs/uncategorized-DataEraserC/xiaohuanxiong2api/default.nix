{
  lib,
  buildGoModule,
  fetchFromGitHub,
  unstableGitUpdater,
}:
buildGoModule (finalAttrs: {
  pname = "xiaohuanxiong2api";
  version = "0-unstable-2026-10-09";
  src = fetchFromGitHub {
    owner = "haoxinyu1";
    repo = "xiaohuanxiong2api";
    rev = "02d2ef158d6900aece29c749fe215d5d75e9f938";
    hash = "sha256-YI2FAgOvf4614lCVlovcopQ67hKWNTx0oE/vov4r5zs=";
  };
  __structuredAttrs = true;
  strictDeps = true;
  vendorHash = null;

  sourceRoot = "source/src";

  ldflags = [
    "-s"
    "-w"
    "-X"
    "xhx2api/internal/version.Version=${finalAttrs.version}"
  ];

  postInstall = ''
    install -Dm644 ${finalAttrs.src}/config.example.json $out/share/doc/xiaohuanxiong2api/config.example.json
  '';

  passthru.updateScript = unstableGitUpdater {
    url = "https://github.com/haoxinyu1/xiaohuanxiong2api";
    hardcodeZeroVersion = true;
  };

  passthru.aiProvenance = [
    {
      agent = "qoder-cn";
      involvement = "authored";
    }
  ];

  meta = {
    description = "OpenAI-compatible reverse proxy for the SenseTime Raccoon client with account pooling and admin panel";
    homepage = "https://github.com/haoxinyu1/xiaohuanxiong2api";
    license = lib.licenses.mit;
    mainProgram = "xhx2api";
    maintainers = import ../maintainers.nix;
  };
})
