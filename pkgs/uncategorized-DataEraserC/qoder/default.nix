{ callPackage, ... }:
(callPackage ../qoder-app-common.nix { }) {
  pname = "qoder";
  version = "0.5.7";
  url = "https://download.qoder.com/qoder-app/releases/latest/Qoder-linux-amd64.deb";
  hash = "sha256-y/uOjgHIUkazQhCibjPfKds+wX0BsMXjifD4V0ZUJCE=";
  appDir = "Qoder";
  executable = "qoder";
  desktopName = "qoder.desktop";
  mainProgram = "qoder";
  description = "Qoder App, Alibaba's agent workbench for human and AI software teams (international edition)";
  homepage = "https://qoder.com/";
  updateScript = ./update.sh;
}
