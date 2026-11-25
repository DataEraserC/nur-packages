{ callPackage, ... }:
(callPackage ../qoder-app-common.nix { }) {
  pname = "qoder";
  version = "0.5.18";
  url = "https://download.qoder.com/qoder-app/releases/latest/Qoder-linux-amd64.deb";
  hash = "sha256-YI8uELFWhdSLsAWJ4bcElm5WmP0fvWauSJp2G8/G6wQ=";
  appDir = "Qoder";
  executable = "qoder";
  desktopName = "qoder.desktop";
  mainProgram = "qoder";
  description = "Qoder App, Alibaba's agent workbench for human and AI software teams (international edition)";
  homepage = "https://qoder.com/";
  updateScript = ./update.sh;
}
