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
    version = "0.2.0";

    src = fetchFromGitHub {
      owner = "DataEraserC";
      repo = "dsh-bas-remote";
      rev = "c5703fb49215fe8123024fd6b1339aab1c44327a";
      hash = "sha256-UX/mRDNo/V8VM/s6WNbWvAaa5KOGTNO5jd9ycMTFsVw=";
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
