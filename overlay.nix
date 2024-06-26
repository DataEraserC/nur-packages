# You can use this file as a nixpkgs overlay. This is useful in the
# case where you don't want to add the whole NUR namespace to your
# configuration.
_self: super:
let
  nameValuePair = n: v: {
    name = n;
    value = v;
  };
  nurAttrs = import ./default.nix null { pkgs = super; };
in
builtins.listToAttrs (map (n: nameValuePair n nurAttrs.${n}) (builtins.attrNames nurAttrs))
