{
  pkgs ? import <nixpkgs> { },
  inputs ? null,
}:
let
  inherit (pkgs) lib;
  inherit (import ./own-packages.nix { inherit lib; }) isOwnPackage;

  nurPkgs = import ../pkgs "nur" {
    inherit pkgs inputs;
  };

  collect =
    prefix: attrs:
    let
      names = builtins.tryEval (builtins.attrNames attrs);
    in
    if !names.success then
      [ ]
    else
      builtins.concatLists (
        map (
          name:
          let
            result = builtins.tryEval attrs.${name};
            attrPath = lib.concatStringsSep "." (prefix ++ [ name ]);
          in
          if !result.success then
            [ ]
          else if lib.isDerivation result.value then
            lib.optional (isOwnPackage result.value) attrPath
          else if lib.isAttrs result.value then
            collect (prefix ++ [ name ]) result.value
          else
            [ ]
        ) names.value
      );

  # Packages are exposed both bare and inside their group (pkgs/default.nix
  # flattens groups); keep the grouped attrPath, like helpers/update.nix does.
  grouped = builtins.filter (lib.hasInfix ".") (collect [ ] nurPkgs);
in
pkgs.writeText "own-packages.txt" (lib.concatStringsSep "\n" (lib.sort lib.lessThan grouped) + "\n")
