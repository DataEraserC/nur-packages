{ lib }:
let
  ownGroup = "uncategorized-DataEraserC";

  ownSelections = [ ownGroup ];
in
rec {
  inherit ownGroup ownSelections;

  isOwnPosition = pos: pos != null && builtins.match ".*/pkgs/${ownGroup}/.*" (toString pos) != null;

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
