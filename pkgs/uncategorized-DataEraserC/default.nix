{
  ifNotNUR,
  inputs,
  loadPackages,
  ...
}:
let
  packages = loadPackages ./. {
    opencode2dsh = p: if inputs == null then ifNotNUR p else p;
    dsh-bas-remote = p: if inputs == null then ifNotNUR p else p;
  };
in
packages
// {
}
