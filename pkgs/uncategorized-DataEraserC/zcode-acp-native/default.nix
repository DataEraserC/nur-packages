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
    rev = "d4d2aac15a77ddb457df43510fa133ed19e71f59";
    sha256 = "19p6b0gg76rr7ps94p9b2bqxy18xjlkm1mgjqqivnp2d2b9lriq9";
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
