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
    rev = "254372197c53d5033ccd6f8f4ab5262b52f820ad";
    sha256 = "0hc1cin4mpirz9zkkc52cx1cvpssw7srdsl9ixfcmb1qr8r80h4x";
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
