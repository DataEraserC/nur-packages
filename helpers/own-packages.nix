{ lib }:
let
  ownGroup = "uncategorized-DataEraserC";

  ownKernelModules = [
    "aw88399-legion-audio-patch"
    "aw88399-legion-firmware"
  ];

  ownKernelModuleAttrPaths = map (n: "kernel-modules.${n}") ownKernelModules;

  ownSelections = [ ownGroup ] ++ ownKernelModuleAttrPaths;
in
rec {
  inherit
    ownGroup
    ownKernelModules
    ownKernelModuleAttrPaths
    ownSelections
    ;

  isOwnPosition =
    pos:
    let
      s = toString pos;
    in
    pos != null
    && (
      builtins.match ".*/pkgs/${ownGroup}/.*" s != null
      || lib.any (n: builtins.match ".*/pkgs/kernel-modules/${n}/.*" s != null) ownKernelModules
    );

  isOwnPackage =
    pkg: isOwnPosition (pkg.meta.position or null) || (pkg.passthru or { }).ownPackage or false;

  matchesSelection = attrPath: sel: attrPath == sel || lib.hasSuffix ".${sel}" attrPath;

  isSelectedAttrPath =
    selections: attrPath:
    lib.any (
      sel:
      matchesSelection attrPath sel || matchesSelection sel attrPath || lib.hasPrefix "${sel}." attrPath
    ) selections;

  isOwnAttrPath = attrPath: isSelectedAttrPath ownSelections attrPath;
}
