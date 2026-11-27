{ callPackage, ... }:
(callPackage ../qoder-common.nix { }) {
  pname = "qoder-cn-ide";
  version = "1.42.0-1795663953";
  url = "https://qoder-ide-cn.oss-cn-hangzhou.aliyuncs.com/qoder/release/lastest/qoder-cn-ide_amd64.deb";
  hash = "sha256-AwkmmXN4YQxZXCFSrDMiiQdTnlDMY5t5r59svEtejJw=";
  appDir = "qoder-cn-ide";
  executable = "qoder-cn-ide";
  desktopName = "qoder-cn-ide.desktop";
  iconName = "qoder-cn-ide";
  mainProgram = "qoder-cn-ide";
  description = "Qoder CN IDE, Alibaba's agentic coding platform (China edition)";
  homepage = "https://qoder.com.cn/";
  updateScript = ./update.sh;
}
