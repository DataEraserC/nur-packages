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
    rev = "7bedaec2f8a96a99814412003b382c142720bcfd";
    sha256 = "0j6x5cbc8bcx1s7q44ip4sbdcqncdkn278d43cqxvf5igv6akd7c";
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
