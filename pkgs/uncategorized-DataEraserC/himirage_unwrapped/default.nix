{
  libsForQt5,
  sources,
  ...
}:
libsForQt5.callPackage ./himirage_unwrapped.nix {
  inherit sources;
}
