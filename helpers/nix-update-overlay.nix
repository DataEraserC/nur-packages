# Applied to every `nix-update` the auto-update run uses: both the update
# scripts baked from this package set and the `<nixpkgs>` seen by update
# scripts that spawn `nix-shell -p nix-update` themselves.
#
# nix-update 1.16.0 evaluates `--flake` packages through the store copy that
# `nix flake metadata --json` reports. Nix 2.35.5+ only keeps the copy of a
# dirty git tree for the lifetime of that command, so the follow-up evaluation
# fails with
#   error: opening file "/nix/store/<hash>-source": No such file or directory
# which broke every `dsh-*` update. Evaluate the working tree instead, like
# nix-update did before that copy was introduced; positions are still mapped
# back to real files by `--arg sanitizePositions true`.
final: prev: {
  nix-update = prev.nix-update.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace nix_update/options.py --replace-fail \
        'return get_flake_store_path(self.import_path)' \
        'return None  # store copy of a dirty tree is deleted before use'
    '';
  });
}
