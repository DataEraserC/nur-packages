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
    rev = "067f94e9ba6801d4503ed93d04c5f7a37d605c4c";
    sha256 = "042kk1fdnhc471aal8rdfb2llkx9dwwa7x9qni7gmdmbv5xsi44n";
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
