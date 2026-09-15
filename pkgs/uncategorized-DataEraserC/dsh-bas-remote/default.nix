{
  lib,
  pkgs,
  inputs ? null,
  fetchFromGitHub,
  nix-update-script,
}:
let
  dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
in
if inputs == null then
  throw "dsh-bas-remote requires the deepseek-harness flake input; evaluate it through the flake (nix build .#dsh-bas-remote)"
else
  dshPkgs.buildDshBundle (finalAttrs: {
    pname = "dsh-bas-remote";
    version = "0.1.0";

    src = fetchFromGitHub {
      owner = "DataEraserC";
      repo = "dsh-bas-remote";
      rev = "e9131de9b23ff92ec421b955a88b330c01128347";
      hash = "sha256-xqVWvf5Bv/mZaQnz1n2MPtrX44kVX2lqSrZkg/10H5Q=";
    };

    npmDepsHash = "sha256-wlmJvOnnHIxuOt8KlSieu2hWeNsi6ykLgm7ni1FQaWk=";

    npmFlags = [ "--legacy-peer-deps" ];

    dontNpmBuild = true;

    linkKernelNodeModules = dshPkgs.dsh-kernel;

    passthru.updateScript = nix-update-script {
      attrPath = "dsh-bas-remote";
      extraArgs = [ "--flake" ];
    };

    meta = {
      changelog = "https://github.com/DataEraserC/dsh-bas-remote/blob/main/CHANGELOG.md";
      description = "SAP Business Application Studio remote dev spaces for DeepSeek Harness";
      homepage = "https://github.com/DataEraserC/dsh-bas-remote";
      license = lib.licenses.asl20;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
