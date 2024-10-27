{
  lib,
  config,
  pkgs ? import <nixpkgs> { },
  ...
}@args:
{
  pkgs = import ./pkgs "nur";
  nixosModules = {
    kata-containers = import ./modules/kata-containers.nix args;
    lyrica = import ./modules/lyrica.nix args;
    nix-cache-attic = import ./modules/nix-cache-attic.nix args;
    nix-cache-cachix = import ./modules/nix-cache-cachix.nix args;
    nix-cache-garnix = import ./modules/nix-cache-garnix.nix args;
    openssl-oqs-provider = import ./modules/openssl-oqs-provider.nix args;
    qemu-user-static-binfmt = import ./modules/qemu-user-static-binfmt.nix args;
    wireguard-remove-lingering-links = import ./modules/wireguard-remove-lingering-links.nix args;
    hkdm = import ./modules/hkdm.nix { inherit lib config pkgs; };
  };
}
