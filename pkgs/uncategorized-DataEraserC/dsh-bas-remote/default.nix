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
  dshPkgs.dsh.buildDshBundle (finalAttrs: {
    pname = "dsh-bas-remote";
    version = "0.3.1";

    src = fetchFromGitHub {
      owner = "DataEraserC";
      repo = "dsh-bas-remote";
      # Follow the release tag, so nix-update only has to bump `version`.
      rev = "v${finalAttrs.version}";
      hash = "sha256-d4h5ZTlzUJwYy2ZUPOA/bwA2F4RCasrtY7AcxEQSt7Q=";
    };

    npmDepsHash = "sha256-wlmJvOnnHIxuOt8KlSieu2hWeNsi6ykLgm7ni1FQaWk=";

    npmFlags = [ "--legacy-peer-deps" ];

    dontNpmBuild = true;

    linkKernelNodeModules = dshPkgs.dsh.dsh-kernel;

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
