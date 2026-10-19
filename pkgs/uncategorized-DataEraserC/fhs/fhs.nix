{ pkgs, ... }:
# create a fhs environment by command `fhs`, so we can run non-nixos packages in nixos!
(
  let
    base = pkgs.appimageTools.defaultFhsEnvArgs;
  in
  pkgs.buildFHSEnv (
    base
    // {
      name = "fhs";
      targetPkgs = pkgs: (base.targetPkgs pkgs) ++ [ pkgs.pkg-config ];
      profile = "export FHS=1";
      runScript = "bash";
      extraOutputsToInstall = [ "dev" ];
      meta = {
        description = "Sandbox environment for running non-NixOS binaries";
        homepage = "https://github.com/DataEraserC/nur-packages";
        license = pkgs.lib.licenses.mit;
        maintainers = import ../maintainers.nix;
      };
    }
  )
)
