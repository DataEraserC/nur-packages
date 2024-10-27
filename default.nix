rec {
  pkgs = import ./pkgs null;
  nixosModules = {
    kata-containers = import ./modules/kata-containers.nix;
    lyrica = import ./modules/lyrica.nix;
    nix-cache-attic = import ./modules/nix-cache-attic.nix;
    nix-cache-cachix = import ./modules/nix-cache-cachix.nix;
    nix-cache-garnix = import ./modules/nix-cache-garnix.nix;
    openssl-oqs-provider = import ./modules/openssl-oqs-provider.nix;
    qemu-user-static-binfmt = import ./modules/qemu-user-static-binfmt.nix;
    wireguard-remove-lingering-links = import ./modules/wireguard-remove-lingering-links.nix;
    hkdm = import ./modules/hkdm.nix;
  };
}
