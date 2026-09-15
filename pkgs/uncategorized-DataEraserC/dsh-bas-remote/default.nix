{
  lib,
  fetchFromGitHub,
  inputs,
  jq,
  pkgs,
  ...
}:

if inputs == null then
  throw "dsh-bas-remote: requires deepseek-harness flake input (not available in NUR bot evaluation)"
else
  let
    dshPkgs = pkgs.extend inputs.deepseek-harness.overlays.default;
  in
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

    nativeBuildInputs = [
      jq
    ];

    passthru = {
      dshBundle = true;
      dshBundleHelper = "buildDshBundle";
      runtimeDeps = [ ];
    };

    meta = {
      description = "SAP Business Application Studio remote dev spaces for DeepSeek Harness";
      homepage = "https://github.com/DataEraserC/dsh-bas-remote";
      license = lib.licenses.asl20;
      maintainers = import ../maintainers.nix;
      platforms = lib.platforms.unix;
    };
  })
