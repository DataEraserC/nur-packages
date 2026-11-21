{ callPackage, ... }:
(callPackage ../qoder-cli-common.nix { }) {
  pname = "qoderclicn";
  executable = "qoderclicn";
  releaseJson = ./release.json;
  description = "Qoder CN CLI, Alibaba's terminal agent client for human and AI software teams (China edition)";
  homepage = "https://qoder.com.cn/cli";
  updateScript = ./update.sh;
}
