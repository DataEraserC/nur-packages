{ callPackage, ... }:
(callPackage ../qoder-app-common.nix { }) {
  pname = "qoder";
  version = "0.5.17";
  url = "https://download.qoder.com/qoder-app/releases/latest/Qoder-linux-amd64.deb";
  hash = "sha256-BCRsKZWd9UHb7lz1b2RrnkWdh6/Ej+9N1DF4iH4W/5A=";
  appDir = "Qoder";
  executable = "qoder";
  desktopName = "qoder.desktop";
  mainProgram = "qoder";
  description = "Qoder App, Alibaba's agent workbench for human and AI software teams (international edition)";
  homepage = "https://qoder.com/";
  updateScript = ./update.sh;
}
