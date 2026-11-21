{ callPackage, ... }:
(callPackage ../qoder-cli-common.nix { }) {
  pname = "qodercli";
  executable = "qodercli";
  releaseJson = ./release.json;
  description = "Qoder CLI, Alibaba's terminal agent client for human and AI software teams (international edition)";
  homepage = "https://qoder.com/cli";
  updateScript = ./update.sh;
}
