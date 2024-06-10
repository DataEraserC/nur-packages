# When you use pkgs.callPackage, parameters here will be filled with packages from Nixpkgs (if there's a match)
{
  stdenv,
  fetchFromGitHub,
  cmake,
  gcc,
}:
let
  # Download source code from GitHub
  src = fetchFromGitHub {
    owner = "Program-Learning";
    repo = "waybar-bluetooth_battery_parse";
    # Commit or tag, note that fetchFromGitHub cannot follow a branch!
    rev = "963b2c1b3e35ac6153267c98805b168809cb9364";
    # Download git submodules, most packages don't need this
    fetchSubmodules = false;
    # Don't know how to calculate the SHA256 here? Comment it out and build the package
    # Nix will raise an error and show the correct hash
    sha256 = "sha256-cafQwzGGki2kAlhwuwVBEO3W+5g5vJi4VKQ7OkwAwl0=";
  };
in
stdenv.mkDerivation rec {
  # Specify package name and version
  pname = "waybar-bluetooth_battery_parse";
  version = "0.0.2";
  inherit src;
  buildInputs = [
    cmake
    gcc
  ];

  # Parallel building, drastically speeds up packaging, enabled by default.
  # You only want to turn this off for one of the rare packages that fails with this.
  enableParallelBuilding = true;
  # If you encounter some weird error when packaging CMake-based software, try enabling this
  # This disables some automatic fixes applied to CMake-based software
  dontFixCmake = true;

  # Add CMake to the building environment, to generate Makefile with it
  nativeBuildInputs = [
    cmake
    gcc
  ];
  installPhase = ''
    mkdir -p $out/bin
    mv waybar-bluetooth_battery_parse $out/bin
  '';
  # look this https://man.archlinux.org/man/waybar-bluetooth.5
  # the only thing to do is set the following in your configuration.nix
  # hardware.bluetooth.settings = {
  #   General = {
  #     Experimental = true;
  #   };
  # };
  broken = true;
  # stdenv.mkDerivation automatically does the rest for you
}
