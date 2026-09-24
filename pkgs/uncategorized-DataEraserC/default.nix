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
    dsh-git-worktree = p: if inputs == null then ifNotNUR p else p;
    modlens = p: if inputs == null then ifNotNUR p else p;
  };
in
removeAttrs packages [ "_docs" ]
// {
}
