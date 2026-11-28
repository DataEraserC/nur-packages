# Native ACP stdio bridge for a running zcode-server.
#
# Fetched by revision so the package tracks the published repository; the
# Cargo.lock in that revision is authoritative for the vendored crates.
{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

let
  src = fetchFromGitHub {
    owner = "desktop-tools-which-may-be-useful";
    repo = "zcode-acp-native";
    rev = "59c5d0ef85c808fbf0964f7333c67ab090c61b10";
    sha256 = "0pl7483pkx6yxdw97mfl8xld1z7azi870zxih83rcl4cdlb0xwc5";
  };
in
rustPlatform.buildRustPackage {
  pname = "zcode-acp-native";
  version = "0.1.0";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  doCheck = true;

  meta = {
    description = "Native ACP stdio bridge for a running zcode-server";
    homepage = "https://github.com/desktop-tools-which-may-be-useful/zcode-acp-native";
    license = lib.licenses.asl20;
    mainProgram = "zcode-acp-native";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
