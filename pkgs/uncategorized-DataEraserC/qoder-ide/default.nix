{ callPackage, ... }:
(callPackage ../qoder-common.nix { }) {
  pname = "qoder-ide";
  version = "1.40.1-1794541531";
  url = "https://download.qoder.com/release/latest/qoder-ide_amd64.deb";
  hash = "sha256-ISwsbWDA30fPB+46U2RmP71a1AQXCmnFtllvWtR536s=";
  appDir = "qoder-ide";
  executable = "qoder-ide";
  desktopName = "qoder-ide.desktop";
  iconName = "qoder-ide";
  mainProgram = "qoder-ide";
  description = "Qoder IDE, Alibaba's agentic coding platform (international edition)";
  homepage = "https://qoder.com/";
  updateScript = ./update.sh;
}
