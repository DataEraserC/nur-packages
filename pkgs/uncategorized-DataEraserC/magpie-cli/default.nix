# magpie, the terminal build: a static Go binary, so nothing to patch.
#
# The TUI, `magpie web`, `magpie serve` and the CLI commands. Plugins still run
# on Bun, which magpie either downloads or takes from MAGPIE_BUN; set it to
# nixpkgs' Bun to keep the downloaded (foreign glibc) copy out of the picture.
{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  xdg-utils,
  bun,
}:
let
  sources = import ../magpie/sources.nix;
  inherit (stdenv.hostPlatform) system;
  arch =
    {
      x86_64-linux = "linux-amd64";
      aarch64-linux = "linux-arm64";
    }
    .${system} or (throw "magpie-cli: no release build for ${system}");
  asset = "magpie-cli-${arch}";
in
stdenv.mkDerivation {
  pname = "magpie-cli";
  inherit (sources) version;

  src = fetchurl {
    url = "https://github.com/yetone/magpie-releases/releases/download/v${sources.version}/${asset}";
    sha256 = sources.assets.${asset};
  };

  dontUnpack = true;
  dontStrip = true;
  dontPatchELF = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/magpie
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/magpie \
      --set-default MAGPIE_BUN ${lib.getExe bun} \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]}
  '';

  meta = {
    description = "Pick the model each AI coding agent on your machine uses (terminal build)";
    homepage = "https://usemagpie.ai/";
    downloadPage = "https://github.com/yetone/magpie-releases/releases";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    maintainers = import ../maintainers.nix;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
