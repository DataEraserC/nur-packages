{ buildFHSEnvChroot, callPackage }:
let
  XMT = callPackage ./XiaoMiToolV2.nix { };
in
buildFHSEnvChroot {
  name = "XiaoMiToolV2";
  targetPkgs = pkgs: with pkgs; [ XMT ];
  profile = ''
    export FHS=1
    XiaoMiToolV2
  '';
}
